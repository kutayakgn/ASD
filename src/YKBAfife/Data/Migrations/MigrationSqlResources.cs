using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore.Migrations;

namespace YKBAfife.Data.Migrations;

internal static partial class MigrationSqlResources
{
    public const string ReviewedDataSafeSqlAnnotation = "Afife:ReviewedDataSafeSql";

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
        Execute(migrationBuilder, "ReferenceData.sql");
        ExecuteMissingSchemaObjects(migrationBuilder, "InitialSchema.sql");
        EnsureCandidateUniquenessContract(migrationBuilder);
    }

    public static void Execute(
        MigrationBuilder migrationBuilder,
        string resourceFileName,
        bool skipWhenBaselineExists = false,
        bool onlyWhenBaselineExists = false)
    {
        if (string.Equals(resourceFileName, "Programmability.sql", StringComparison.OrdinalIgnoreCase))
        {
            Execute(
                migrationBuilder,
                "ProgrammabilityPrerequisites.sql",
                skipWhenBaselineExists,
                onlyWhenBaselineExists);
        }

        var sql = Read(resourceFileName);

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
        var assembly = typeof(MigrationSqlResources).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .SingleOrDefault(name => name.EndsWith($".Migrations.Scripts.{resourceFileName}",
                StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException(
                $"Embedded migration resource '{resourceFileName}' was not found.");

        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException(
                $"Embedded migration resource '{resourceName}' could not be opened.");
        using var reader = new StreamReader(stream);
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
}
