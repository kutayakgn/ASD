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
            if (!catalog.Constraints.Contains(match.Groups["name"].Value))
            {
                missing.Add($"constraint {match.Groups["name"].Value}");
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

        var unexpectedTriggers = catalog.Triggers.Except(
            expectedTriggers, StringComparer.OrdinalIgnoreCase);
        foreach (var trigger in unexpectedTriggers)
        {
            missing.Add($"unexpected trigger {trigger}");
        }

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                "Database schema drift detected. Missing objects: " +
                string.Join(", ", missing.Order(StringComparer.OrdinalIgnoreCase)));
        }
    }

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
            SELECT N'R', tr.name FROM sys.triggers tr WHERE tr.parent_class = 1;
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