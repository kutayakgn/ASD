using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore.Migrations;

namespace YKBAfife.Data.Migrations;

internal static partial class MigrationSqlResources
{
    public const string ReviewedDataSafeSqlAnnotation = "Afife:ReviewedDataSafeSql";

    public static void ExecuteProgrammability(MigrationBuilder migrationBuilder)
    {
        foreach (var sql in ReadCanonicalDatabaseObjectFiles())
        {
            ExecuteSql(migrationBuilder, sql);
        }
    }

    public static string ReadCanonicalDatabaseObjects() =>
        string.Join(
            Environment.NewLine + "GO" + Environment.NewLine,
            ReadCanonicalDatabaseObjectFiles());

    private static IReadOnlyList<string> ReadCanonicalDatabaseObjectFiles()
    {
        var assembly = typeof(MigrationSqlResources).Assembly;
        var resources = assembly.GetManifestResourceNames()
            .Where(name => name.Contains(
                ".Migrations.DatabaseObjects.",
                StringComparison.OrdinalIgnoreCase))
            .Where(name => !name.Contains(
                ".50-ReferenceData.",
                StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (resources.Length == 0)
        {
            throw new InvalidOperationException(
                "No embedded canonical database modules were found.");
        }

        return resources.Select(resource => ReadResource(assembly, resource)).ToArray();
    }

    public static void ExecuteVersionedDatabaseObjects(
        MigrationBuilder migrationBuilder,
        string migrationName,
        string directionFile)
    {
        if (!Regex.IsMatch(migrationName, "^[A-Za-z0-9_]+$") ||
            directionFile is not ("Up.sql" or "Down.sql"))
        {
            throw new ArgumentException("Invalid versioned database object resource name.");
        }

        ExecuteSql(migrationBuilder, ReadVersionSection(
            migrationName, directionFile[..^4].ToUpperInvariant(), []));
    }

    public static void AdoptSquashedBaseline(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NOT NULL
            BEGIN
                DELETE FROM dbo.__EFMigrationsHistory;
            END;
            """)
            .Annotation(ReviewedDataSafeSqlAnnotation, true);
    }

    /// <summary>
    /// Brings an empty, partial legacy, or previously managed database to the
    /// canonical baseline in the only supported dependency order. The caller
    /// must set AfifeBaselineAlreadyExists before invoking this pipeline.
    /// </summary>
    public static void ExecuteLegacyBaselineUpgrade(MigrationBuilder migrationBuilder)
    {
        Execute(migrationBuilder, "PrepareLegacyForm.sql", onlyWhenBaselineExists: true);
        ExecuteMissingTables(migrationBuilder, "InitialSchema.sql");
        Execute(migrationBuilder, "LegacyUpgrade.sql", onlyWhenBaselineExists: true);
        Execute(migrationBuilder, "PrepareLegacyUsers.sql", onlyWhenBaselineExists: true);
        // Baseline bootstrap is frozen with the legacy adapters. Future reference
        // changes are captured by their own migration, never by mutating this step.
        Execute(migrationBuilder, "BaselineReferenceData.sql");
        ExecuteMissingSchemaObjects(migrationBuilder, "InitialSchema.sql");
        EnsureCandidateUniquenessContract(migrationBuilder);
    }

    public static void Execute(
        MigrationBuilder migrationBuilder,
        string resourceFileName,
        bool skipWhenBaselineExists = false,
        bool onlyWhenBaselineExists = false)
    {
        var sql = Read(resourceFileName);
        ExecuteSql(
            migrationBuilder,
            sql,
            skipWhenBaselineExists,
            onlyWhenBaselineExists);
    }

    private static void ExecuteSql(
        MigrationBuilder migrationBuilder,
        string sql,
        bool skipWhenBaselineExists = false,
        bool onlyWhenBaselineExists = false)
    {
        foreach (var batch in GoBatchRegex().Split(sql))
        {
            var command = batch.Trim();
            if (command.Length == 0)
            {
                continue;
            }

            if (skipWhenBaselineExists)
            {
                command = WrapConditionalDynamicSql(
                    command,
                    "TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1");
            }

            if (onlyWhenBaselineExists)
            {
                command = WrapConditionalDynamicSql(
                    command,
                    "TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) = 1");
            }
            else if (!skipWhenBaselineExists && CreateOrAlterModuleRegex().IsMatch(command))
            {
                command = $"EXEC sys.sp_executesql N'{command.Replace("'", "''")}';";
            }
            migrationBuilder.Sql(command, suppressTransaction: false)
                .Annotation(ReviewedDataSafeSqlAnnotation, true);
        }
    }

    public static void ExecuteMissingTables(
        MigrationBuilder migrationBuilder,
        string resourceFileName)
    {
        foreach (var batch in GoBatchRegex().Split(Read(resourceFileName)))
        {
            var command = batch.Trim();
            var match = CreateTableRegex().Match(command);
            if (!match.Success)
            {
                continue;
            }

            var schema = match.Groups["schema"].Value;
            var table = match.Groups["table"].Value;
            command = $"""
                IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
                    RETURN;
                IF OBJECT_ID(N'[{schema}].[{table}]', N'U') IS NOT NULL
                    RETURN;

                {command}
                """;
            migrationBuilder.Sql(command)
                .Annotation(ReviewedDataSafeSqlAnnotation, true);
        }
    }

    public static void ExecuteMissingSchemaObjects(
        MigrationBuilder migrationBuilder,
        string resourceFileName)
    {
        foreach (var batch in GoBatchRegex().Split(Read(resourceFileName)))
        {
            var command = batch.Trim();
            if (command.Length == 0 || CreateTableRegex().IsMatch(command))
            {
                continue;
            }

            var index = CreateIndexRegex().Match(command);
            if (index.Success)
            {
                var indexName = index.Groups["name"].Value;
                if (string.Equals(
                        indexName,
                        "UX_PlayAwardCategories_Current_Play_Category_Role",
                        StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(
                        indexName,
                        "UX_PlayAwardCategories_FormSourceSlot",
                        StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                AddReviewedSql(migrationBuilder, $"""
                    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
                        RETURN;
                    IF EXISTS
                    (
                        SELECT 1 FROM sys.indexes
                        WHERE object_id = OBJECT_ID(N'[{index.Groups["schema"].Value}].[{index.Groups["table"].Value}]')
                          AND name = N'{index.Groups["name"].Value.Replace("'", "''")}'
                    )
                        RETURN;

                    {command}
                    """);
                continue;
            }

            var defaultValue = AddDefaultRegex().Match(command);
            if (defaultValue.Success)
            {
                AddReviewedSql(migrationBuilder, $"""
                    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
                        RETURN;
                    IF EXISTS
                    (
                        SELECT 1
                        FROM sys.default_constraints AS dc
                        INNER JOIN sys.columns AS col
                            ON col.object_id = dc.parent_object_id
                           AND col.column_id = dc.parent_column_id
                        WHERE dc.parent_object_id =
                              OBJECT_ID(N'[{defaultValue.Groups["schema"].Value}].[{defaultValue.Groups["table"].Value}]')
                          AND col.name = N'{defaultValue.Groups["column"].Value.Replace("'", "''")}'
                    )
                        RETURN;

                    {command}
                    """);
                continue;
            }

            var constraint = AddConstraintRegex().Match(command);
            if (constraint.Success)
            {
                AddReviewedSql(migrationBuilder, $"""
                    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
                        RETURN;
                    IF OBJECT_ID(
                        N'[{constraint.Groups["schema"].Value}].[{constraint.Groups["name"].Value}]') IS NOT NULL
                        RETURN;

                    {command}
                    """);
                continue;
            }

            var checkConstraint = CheckConstraintRegex().Match(command);
            if (checkConstraint.Success)
            {
                AddReviewedSql(migrationBuilder, $"""
                    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
                        RETURN;
                    IF OBJECT_ID(
                        N'[{checkConstraint.Groups["schema"].Value}].[{checkConstraint.Groups["name"].Value}]') IS NULL
                        RETURN;

                    {command}
                    """);
            }
        }
    }

    private static string WrapConditionalDynamicSql(string sql, string condition) =>
        $"IF {condition} EXEC sys.sp_executesql N'{sql.Replace("'", "''")}';";
    private static void AddReviewedSql(MigrationBuilder migrationBuilder, string sql) =>
        migrationBuilder.Sql(sql)
            .Annotation(ReviewedDataSafeSqlAnnotation, true);

    public static void EnsureCandidateUniquenessContract(MigrationBuilder migrationBuilder) =>
        AddReviewedSql(migrationBuilder,
            """
            IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
            BEGIN
                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'UX_PlayAwardCategories_Current_Play_Category_Role'
                )
                    DROP INDEX [UX_PlayAwardCategories_Current_Play_Category_Role]
                        ON dbo.PlayAwardCategories;

                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'IX_PlayAwardCategories_Current_Play_Category_Role'
                )
                    DROP INDEX [IX_PlayAwardCategories_Current_Play_Category_Role]
                        ON dbo.PlayAwardCategories;

                CREATE NONCLUSTERED INDEX [IX_PlayAwardCategories_Current_Play_Category_Role]
                    ON dbo.PlayAwardCategories
                       (PlayId, AwardCategoryCode, RoleCode, IsCurrent)
                    WHERE IsCurrent = 1 AND IsPublished = 1;

                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'UX_PlayAwardCategories_FormSourceSlot'
                )
                    DROP INDEX [UX_PlayAwardCategories_FormSourceSlot]
                        ON dbo.PlayAwardCategories;

                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'IX_PlayAwardCategories_FormSourceSlot'
                )
                    DROP INDEX [IX_PlayAwardCategories_FormSourceSlot]
                        ON dbo.PlayAwardCategories;

                CREATE NONCLUSTERED INDEX [IX_PlayAwardCategories_FormSourceSlot]
                    ON dbo.PlayAwardCategories
                       (PlayId, AwardCategoryCode, SourceFormCandidateOrder)
                    WHERE SourceFormCandidateOrder IS NOT NULL AND IsCurrent = 1;
            END;
            """);

    public static string Read(string resourceFileName)
    {
        // Keep historical migrations (including Seed call positions) unchanged
        // while storing each version in one readable SQL package.
        var versionMatch = VersionFileRegex().Match(resourceFileName);
        if (versionMatch.Success)
        {
            return ReadVersionSection(
                versionMatch.Groups["version"].Value,
                versionMatch.Groups["section"].Value.ToUpperInvariant(), []);
        }

        var assembly = typeof(MigrationSqlResources).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .SingleOrDefault(name => name.EndsWith($".{resourceFileName}",
                StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException(
                $"Embedded migration resource '{resourceFileName}' was not found.");

        return ReadResource(assembly, resourceName);
    }

    private static string ReadVersionSection(
        string version,
        string section,
        HashSet<string> visited) =>
        ReadVersionSection(version, section, visited, Read);

    private static string ReadVersionSection(
        string version,
        string section,
        HashSet<string> visited,
        Func<string, string> readPackage)
    {
        if (!Regex.IsMatch(version, "^[A-Za-z0-9_]+$", RegexOptions.CultureInvariant) ||
            section is not ("UP" or "DOWN" or "SEED"))
        {
            throw new ArgumentException("Invalid SQL package section.");
        }
        var key = $"{version}/{section}";
        if (!visited.Add(key))
        {
            throw new InvalidOperationException($"Circular SQL package reference: {key}.");
        }

        var package = readPackage($"{version}.sql");
        // StreamReader removes a file-level BOM. Keep the text parser consistent
        // for injected/package-copy readers, but never strip a BOM inside SQL.
        if (package.StartsWith('\uFEFF')) package = package[1..];
        var options = RegexOptions.Multiline | RegexOptions.CultureInvariant;
        var inline = Regex.Matches(package,
            $@"^-- <AFIFE:{section}>\r?\n(?<sql>[\s\S]*?)\r?\n-- </AFIFE:{section}>\r?$", options);
        var reference = Regex.Matches(package,
            $@"^-- <AFIFE:{section}:REFERENCE=(?<version>[A-Za-z0-9_]+):(?<section>UP|DOWN|SEED)>\r?$", options);
        if (inline.Count + reference.Count != 1)
        {
            throw new InvalidOperationException(
                $"Expected exactly one {section} section in {version}.sql.");
        }

        var sql = inline.Count == 1
            ? inline[0].Groups["sql"].Value
            : ReadVersionSection(
                reference[0].Groups["version"].Value,
                reference[0].Groups["section"].Value,
                visited,
                readPackage);
        var hash = Regex.Matches(package,
            $@"^-- <AFIFE:SHA256:{section}=(?<hash>[A-F0-9]{{64}})>\r?$", options);
        var actualHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
        var canonicalMarkers = Regex.Matches(package,
            $@"^-- <AFIFE:SHA256-LF:{section}(?=[=:>\s])", options);
        var canonicalHash = Regex.Matches(package,
            $@"^-- <AFIFE:SHA256-LF:{section}=(?<raw>[A-F0-9]{{64}}):(?<hash>[A-F0-9]{{64}})>\r?$", options);
        // Keep the original raw digest frozen. The paired digest permits ONLY
        // CRLF/LF transport changes, including historically mixed line endings.
        // Spaces, literals, Unicode and trailing newlines remain significant.
        // If canonical metadata exists it must be valid even when raw bytes match.
        var canonicalMatches = canonicalMarkers.Count == 1 && canonicalHash.Count == 1 &&
            hash.Count == 1 && canonicalHash[0].Groups["raw"].Value == hash[0].Groups["hash"].Value &&
            canonicalHash[0].Groups["hash"].Value == Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(sql.Replace("\r\n", "\n", StringComparison.Ordinal))));
        if (hash.Count != 1 || (canonicalMarkers.Count > 0
                ? !canonicalMatches
                : hash[0].Groups["hash"].Value != actualHash))
        {
            throw new InvalidOperationException(
                $"SQL payload hash mismatch for {key}. Historic migration SQL must not be edited. " +
                $"Actual UTF-8 SHA256: {actualHash}. " +
                "Use the complete matching application build and SQL packages; " +
                "do not reset migration history or regenerate hashes for edited SQL.");
        }
        var batches = Regex.Matches(package,
            $@"^-- <AFIFE:BATCHES:{section}=(?<count>[0-9]+)>\r?$", options);
        if (batches.Count != 1 ||
            !int.TryParse(batches[0].Groups["count"].Value, out var expectedCount) ||
            GoBatchRegex().Split(sql).Count(batch => !string.IsNullOrWhiteSpace(batch)) != expectedCount)
        {
            throw new InvalidOperationException($"SQL command batch count mismatch for {key}.");
        }
        return sql;
    }

    private static string ReadResource(Assembly assembly, string resourceName)
    {
        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException(
                $"Embedded migration resource '{resourceName}' could not be opened.");
        using var reader = new StreamReader(stream, new UTF8Encoding(false, true), detectEncodingFromByteOrderMarks: true);
        return reader.ReadToEnd();
    }
    [GeneratedRegex(@"CREATE\s+TABLE\s+\[(?<schema>[^]]+)\]\.\[(?<table>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex CreateTableRegex();

    [GeneratedRegex(@"CREATE\s+(?:UNIQUE\s+)?(?:NONCLUSTERED\s+)?INDEX\s+\[(?<name>[^]]+)\]\s+ON\s+\[(?<schema>[^]]+)\]\.\[(?<table>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex CreateIndexRegex();

    [GeneratedRegex(@"ALTER\s+TABLE\s+\[(?<schema>[^]]+)\]\.\[(?<table>[^]]+)\]\s+ADD\s+(?:CONSTRAINT\s+\[[^]]+\]\s+)?DEFAULT[\s\S]+?FOR\s+\[(?<column>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex AddDefaultRegex();

    [GeneratedRegex(@"ALTER\s+TABLE\s+\[(?<schema>[^]]+)\]\.\[(?<table>[^]]+)\][\s\S]+?ADD\s+CONSTRAINT\s+\[(?<name>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex AddConstraintRegex();

    [GeneratedRegex(@"ALTER\s+TABLE\s+\[(?<schema>[^]]+)\]\.\[(?<table>[^]]+)\]\s+CHECK\s+CONSTRAINT\s+\[(?<name>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex CheckConstraintRegex();
    [GeneratedRegex(@"CREATE\s+OR\s+ALTER\s+(?:PROCEDURE|TRIGGER)\b", RegexOptions.IgnoreCase)]
    private static partial Regex CreateOrAlterModuleRegex();
    [GeneratedRegex(@"^\s*GO\s*(?:--.*)?$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex GoBatchRegex();

    [GeneratedRegex(@"^(?<version>[A-Za-z0-9_]+)\.(?<section>Up|Down|Seed)\.sql$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex VersionFileRegex();
}
