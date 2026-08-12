using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace YKBAfife.Data.Migrations;

internal static partial class DatabaseSchemaValidator
{
    public static async Task ValidateAsync(
        AfifeContext context,
        SqlConnection connection,
        CancellationToken cancellationToken)
    {
        var missing = new List<string>();
        var catalog = await ReadCatalogAsync(connection, cancellationToken);

        foreach (var entityType in context.Model.GetEntityTypes())
        {
            var table = entityType.GetTableName();
            if (table is null)
            {
                continue;
            }

            var schema = entityType.GetSchema() ?? "dbo";
            var tableKey = $"{schema}.{table}";
            if (!catalog.Tables.Contains(tableKey))
            {
                missing.Add($"table {tableKey}");
                continue;
            }

            var storeObject = StoreObjectIdentifier.Table(table, schema);
            foreach (var property in entityType.GetProperties())
            {
                var column = property.GetColumnName(storeObject);
                if (column is not null && !catalog.Columns.Contains($"{tableKey}.{column}"))
                {
                    missing.Add($"column {tableKey}.{column}");
                }
            }

            if (entityType.FindPrimaryKey() is not null &&
                !catalog.PrimaryKeyTables.Contains(tableKey))
            {
                missing.Add($"primary key on {tableKey}");
            }

            var hasIsPublished = entityType.GetProperties().Any(property =>
                string.Equals(property.GetColumnName(storeObject), "IsPublished",
                    StringComparison.OrdinalIgnoreCase));
            if (hasIsPublished && !catalog.IsPublishedDefaultOneTables.Contains(tableKey))
            {
                missing.Add($"default 1 for {tableKey}.IsPublished");
            }
        }

        var schemaSql = MigrationSqlResources.Read("InitialSchema.sql");
        foreach (Match match in IndexRegex().Matches(schemaSql))
        {
            if (!catalog.Indexes.Contains(match.Groups["name"].Value))
            {
                missing.Add($"index {match.Groups["name"].Value}");
            }
        }
        foreach (Match match in ConstraintRegex().Matches(schemaSql))
        {
            var constraintName = match.Groups["name"].Value;
            if (constraintName.StartsWith("PK_", StringComparison.OrdinalIgnoreCase) ||
                constraintName.EndsWith("_IsPublished_SoftDelete", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (!catalog.Constraints.Contains(constraintName))
            {
                missing.Add($"constraint {constraintName}");
            }
        }

        var programmableSql = MigrationSqlResources.Read("Programmability.sql");
        foreach (Match match in ProcedureRegex().Matches(programmableSql))
        {
            if (!catalog.Procedures.Contains(match.Groups["name"].Value))
            {
                missing.Add($"procedure dbo.{match.Groups["name"].Value}");
            }
        }
        var expectedTriggers = TriggerRegex().Matches(programmableSql)
            .Select(match => match.Groups["name"].Value)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var auditSql = MigrationSqlResources.Read("AuditTriggers.sql");
        expectedTriggers.UnionWith(TriggerRegex().Matches(auditSql)
            .Select(match => match.Groups["name"].Value));

        foreach (var table in catalog.Tables.Where(x =>
                     !x.EndsWith(".AdminLogs", StringComparison.OrdinalIgnoreCase) &&
                     !x.EndsWith(".UsersLog", StringComparison.OrdinalIgnoreCase) &&
                     !x.EndsWith(".__EFMigrationsHistory", StringComparison.OrdinalIgnoreCase)))
        {
            var parts = table.Split('.', 2);
            var auditTrigger = $"TR_AdminAudit_{parts[0]}_{parts[1]}";
            expectedTriggers.Add(auditTrigger);
        }

        foreach (var trigger in expectedTriggers)
        {
            if (!catalog.Triggers.Contains(trigger))
            {
                missing.Add($"trigger dbo.{trigger}");
            }
        }

        foreach (var foreignKey in catalog.CascadingForeignKeys)
        {
            missing.Add($"foreign key {foreignKey} must use ON UPDATE/DELETE NO ACTION");
        }

        var unexpectedTriggers = catalog.Triggers.Except(
            expectedTriggers, StringComparer.OrdinalIgnoreCase);
        foreach (var trigger in unexpectedTriggers)
        {
            missing.Add($"unexpected trigger {trigger}");
        }

        if (missing.Count == 0)
        {
            await ValidateReferenceDataAsync(connection, missing, cancellationToken);
        }

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                "Database schema drift detected. Missing or invalid objects: " +
                string.Join(", ", missing.Order(StringComparer.OrdinalIgnoreCase)));
        }
    }

    private static async Task ValidateReferenceDataAsync(
        SqlConnection connection,
        ICollection<string> invalid,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT N'Role', RoleCode, RoleName, IsPublished, NULL, NULL
            FROM dbo.Roles WHERE RoleCode IN (1, 2)
            UNION ALL
            SELECT N'AwardCategory', CategoryCode, CategoryName, IsPublished,
                   MultiCandidate, CONVERT(nvarchar(50), HasRoleAndPhoto)
            FROM dbo.AwardCategories WHERE CategoryCode BETWEEN 1001 AND 1012
            UNION ALL
            SELECT N'PlayStatus', StatusCode, StatusName, IsPublished,
                   NULL, StatusColor
            FROM dbo.PlayStatuses WHERE StatusCode BETWEEN 1 AND 6;
            """;

        var actual = new Dictionary<(string Type, int Code), ReferenceRow>();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = (reader.GetString(0), reader.GetInt32(1));
            actual[key] = new ReferenceRow(
                reader.GetString(2),
                reader.GetBoolean(3),
                reader.IsDBNull(4) ? null : reader.GetBoolean(4),
                reader.IsDBNull(5) ? null : reader.GetString(5));
        }

        foreach (var expected in RequiredReferenceRows)
        {
            if (!actual.TryGetValue(expected.Key, out var row))
            {
                invalid.Add($"reference data {expected.Key.Type} code {expected.Key.Code} is missing");
                continue;
            }

            if (row != expected.Value)
            {
                invalid.Add(
                    $"reference data {expected.Key.Type} code {expected.Key.Code} " +
                    $"expected [{expected.Value}] but found [{row}]");
            }
        }
    }

    private static readonly IReadOnlyDictionary<(string Type, int Code), ReferenceRow>
        RequiredReferenceRows = new Dictionary<(string, int), ReferenceRow>
        {
            [("Role", 1)] = new("Koordinatör", true, null, null),
            [("Role", 2)] = new("Jüri", true, null, null),
            [("AwardCategory", 1001)] = new("Yılın En Başarılı Oyunu", true, false, "0"),
            [("AwardCategory", 1002)] = new("Yılın En Başarılı Yönetmeni", true, false, "1"),
            [("AwardCategory", 1003)] = new("Yılın En Başarılı Kadın Oyuncusu", true, true, "1"),
            [("AwardCategory", 1004)] = new("Yılın En Başarılı Erkek Oyuncusu", true, true, "1"),
            [("AwardCategory", 1005)] = new("Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu", true, true, "1"),
            [("AwardCategory", 1006)] = new("Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu", true, true, "1"),
            [("AwardCategory", 1007)] = new("Yılın En Başarılı Sahne Tasarımı", true, true, "1"),
            [("AwardCategory", 1008)] = new("Yılın En Başarılı Giysi Tasarımı", true, true, "1"),
            [("AwardCategory", 1009)] = new("Yılın En Başarılı Sahne Müziği", true, true, "1"),
            [("AwardCategory", 1010)] = new("Yılın En Başarılı Işık Tasarımı", true, true, "1"),
            [("AwardCategory", 1011)] = new("Yılın En Başarılı Hareket Düzeni (Kareografisi)", true, true, "1"),
            [("AwardCategory", 1012)] = new("Yılın En Başarılı Genç Kuşak Sanatçısı", true, true, "1"),
            [("PlayStatus", 1)] = new("Oylama Aktif", true, null, "#27ae60"),
            [("PlayStatus", 2)] = new("Değerlendirmeyecek Oyun", true, null, "#d9322d"),
            [("PlayStatus", 3)] = new("Başvuru Yapmayacak Oyun", true, null, "#2CA9E8"),
            [("PlayStatus", 4)] = new("Sahnelenmeyecek Oyun", true, null, "#ac48ed"),
            [("PlayStatus", 5)] = new("Başvurusu Olmayan Oyun", true, null, "#ffffff"),
            [("PlayStatus", 6)] = new("Sistemde Aktif Değil", true, null, "#ffc400")
        };

    private sealed record ReferenceRow(
        string Name,
        bool IsPublished,
        bool? Flag,
        string? Value);
    private static async Task<Catalog> ReadCatalogAsync(
        SqlConnection connection,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT N'T', s.name + N'.' + t.name
            FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
            UNION ALL
            SELECT N'C', s.name + N'.' + t.name + N'.' + c.name
            FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            UNION ALL
            SELECT N'I', i.name FROM sys.indexes i
            WHERE i.name IS NOT NULL
            UNION ALL
            SELECT N'K', o.name FROM sys.objects o
            WHERE o.type IN (N'PK', N'UQ', N'F', N'C', N'D')
            UNION ALL
            SELECT N'P', p.name FROM sys.procedures p
            UNION ALL
            SELECT N'R', tr.name FROM sys.triggers tr WHERE tr.parent_class = 1
            UNION ALL
            SELECT N'F', fk.name FROM sys.foreign_keys fk
            WHERE fk.delete_referential_action <> 0
               OR fk.update_referential_action <> 0
            UNION ALL
            SELECT N'Q', s.name + N'.' + t.name
            FROM sys.key_constraints pk
            JOIN sys.tables t ON t.object_id = pk.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE pk.type = N'PK'
            UNION ALL
            SELECT N'B', s.name + N'.' + t.name
            FROM sys.default_constraints dc
            JOIN sys.columns c ON c.object_id = dc.parent_object_id
                              AND c.column_id = dc.parent_column_id
            JOIN sys.tables t ON t.object_id = dc.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE c.name = N'IsPublished'
              AND REPLACE(REPLACE(REPLACE(dc.definition, N'(', N''), N')', N''), N' ', N'') = N'1';
            """;

        var result = new Catalog();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var kind = reader.GetString(0);
            var name = reader.GetString(1);
            (kind switch
            {
                "T" => result.Tables,
                "C" => result.Columns,
                "I" => result.Indexes,
                "K" => result.Constraints,
                "P" => result.Procedures,
                "R" => result.Triggers,
                "F" => result.CascadingForeignKeys,
                "Q" => result.PrimaryKeyTables,
                "B" => result.IsPublishedDefaultOneTables,
                _ => throw new DataException($"Unknown schema catalog kind '{kind}'.")
            }).Add(name);
        }

        return result;
    }

    private sealed class Catalog
    {
        public HashSet<string> Tables { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Columns { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Indexes { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Constraints { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Procedures { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Triggers { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> CascadingForeignKeys { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> PrimaryKeyTables { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> IsPublishedDefaultOneTables { get; } = new(StringComparer.OrdinalIgnoreCase);
    }

    [GeneratedRegex(@"CREATE\s+(?:UNIQUE\s+)?(?:NONCLUSTERED\s+)?INDEX\s+\[(?<name>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex IndexRegex();

    [GeneratedRegex(@"CONSTRAINT\s+\[(?<name>[^]]+)\]",
        RegexOptions.IgnoreCase)]
    private static partial Regex ConstraintRegex();

    [GeneratedRegex(@"CREATE\s+OR\s+ALTER\s+PROCEDURE\s+(?:\[?dbo\]?\.)?\[?(?<name>[A-Za-z0-9_]+)\]?",
        RegexOptions.IgnoreCase)]
    private static partial Regex ProcedureRegex();

    [GeneratedRegex(@"CREATE\s+OR\s+ALTER\s+TRIGGER\s+(?:\[?dbo\]?\.)?\[?(?<name>[A-Za-z0-9_]+)\]?",
        RegexOptions.IgnoreCase)]
    private static partial Regex TriggerRegex();
}
