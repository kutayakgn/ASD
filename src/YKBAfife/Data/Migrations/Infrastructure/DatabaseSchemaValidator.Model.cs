using System.Data;
using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;

namespace YKBAfife.Data.Migrations;

internal static partial class DatabaseSchemaValidator
{
    // Active EF metadata owns relational requirements. Historical baseline SQL
    // must never force a developer to keep a retired index/constraint forever.
    private static async Task ValidateModelRulesAsync(
        AfifeContext context, SqlConnection connection, ICollection<string> invalid,
        CancellationToken cancellationToken)
    {
        var actual = await ReadModelRulesAsync(connection, cancellationToken);
        var model = context.GetService<IDesignTimeModel>().Model;
        var checkedObjects = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var entity in model.GetEntityTypes())
        {
            var table = entity.GetTableName();
            if (table is null) continue;
            var schema = entity.GetSchema() ?? "dbo";
            var store = StoreObjectIdentifier.Table(table, schema);
            var tableKey = $"{schema}.{table}";
            string Column(IReadOnlyProperty property) => property.GetColumnName(store)!;

            foreach (var index in entity.GetIndexes())
            {
                var name = index.GetDatabaseName(store);
                if (name is null) continue;
                var key = $"{tableKey}.{name}";
                if (!checkedObjects.Add(key)) continue;
                // Historical snapshots declare this redundant nonunique log
                // index, but deployed schemas use the covering composite one.
                // Preserve both model and database until an explicit migration
                // reconciles it; this is not a business uniqueness constraint.
                if (key == "dbo.AdminLogs.IX_AdminLogs_CorrelationId1" && !actual.Indexes.ContainsKey(key)) continue;
                // Old installations intentionally omitted convention-only FK
                // lookup indexes. They are performance aids, not constraints.
                // An explicit filter/include/sort or business unique index is
                // always required; do not invent new DDL just for a refactor.
                var conventionalForeignKeyLookup = !index.IsUnique && index.GetFilter(store) is null &&
                    index.GetIncludeProperties() is null && index.IsDescending is null &&
                    name == $"IX_{table}_{string.Join("_", index.Properties.Select(Column))}" &&
                    entity.GetForeignKeys().Any(foreignKey => foreignKey.Properties.SequenceEqual(index.Properties));
                if (conventionalForeignKeyLookup && !actual.Indexes.ContainsKey(key)) continue;
                var columns = index.Properties.Select(Column).ToArray();
                var descending = index.IsDescending?.ToArray() ?? new bool[columns.Length];
                if (descending.Length == 0) descending = Enumerable.Repeat(true, columns.Length).ToArray();
                var included = (index.GetIncludeProperties() ?? Array.Empty<string>())
                    .Select(property => Column(entity.FindProperty(property)!)).ToHashSet(StringComparer.OrdinalIgnoreCase);
                if (!actual.Indexes.TryGetValue(key, out var row) || row.Disabled ||
                    row.Unique != index.IsUnique || !row.Columns.SequenceEqual(columns, StringComparer.OrdinalIgnoreCase) ||
                    (index.IsDescending is not null && !row.Descending.SequenceEqual(descending)) || !row.Included.SetEquals(included) ||
                    NormalizeSql(row.Sql) != NormalizeSql(index.GetFilter(store)))
                    invalid.Add($"index {key} (columns/order/unique/filter/include)");
            }
            foreach (var keyDefinition in entity.GetKeys())
            {
                var name = keyDefinition.GetName(store);
                if (name is null) continue;
                var key = $"{tableKey}.{name}";
                if (!checkedObjects.Add(key)) continue;
                var columns = keyDefinition.Properties.Select(Column).ToArray();
                var tableKeys = actual.Keys.Where(entry =>
                    string.Equals(entry.Value.Table, tableKey, StringComparison.OrdinalIgnoreCase)).ToArray();
                // Legacy databases may have SQL Server-generated or manually
                // assigned constraint names. Names do not change the key rule;
                // require an enabled PK/UQ on this table's exact ordered columns.
                // A unique index must never substitute for a primary/alternate key.
                if (!tableKeys.Any(entry =>
                        entry.Value.Primary == keyDefinition.IsPrimaryKey() && !entry.Value.Disabled && entry.Value.Unique &&
                        entry.Value.Columns.SequenceEqual(columns, StringComparer.OrdinalIgnoreCase)))
                {
                    var kind = keyDefinition.IsPrimaryKey() ? "PK" : "UQ";
                    var found = tableKeys.Length == 0 ? "none" : string.Join("; ", tableKeys.Select(entry =>
                        $"{entry.Key} {(entry.Value.Primary ? "PK" : "UQ")} ({string.Join(",", entry.Value.Columns)})" +
                        (entry.Value.Disabled ? " disabled" : "") + (!entry.Value.Unique ? " nonunique" : "")));
                    invalid.Add($"key {key} (expected {kind} ({string.Join(",", columns)}); found {found})");
                }
            }
            foreach (var foreignKey in entity.GetForeignKeys())
            {
                var name = foreignKey.GetConstraintName();
                if (name is null) continue;
                var key = $"{tableKey}.{name}";
                if (!checkedObjects.Add(key)) continue;
                var principalTable = foreignKey.PrincipalEntityType.GetTableName()!;
                var principalSchema = foreignKey.PrincipalEntityType.GetSchema() ?? "dbo";
                var principalStore = StoreObjectIdentifier.Table(principalTable, principalSchema);
                // EF has no ON UPDATE mapping. Editable Group.Code is the sole
                // SQL-managed update cascade; every other FK stays NO ACTION.
                var expectedUpdateAction = principalSchema == "dbo" && principalTable == "Group" &&
                    foreignKey.PrincipalKey.Properties.Any(property => property.GetColumnName(principalStore) == "Code") ? 1 : 0;
                actual.ForeignKeys.TryGetValue(key, out var row);
                // A company schema can preserve its legacy-named cascade FK
                // beside the equivalent model-named NO ACTION FK. Require the
                // same dependent/principal objects and every ordered column;
                // a cascade elsewhere on the table is never a substitute.
                var validUpdateAction = row is not null && (row.UpdateAction == expectedUpdateAction ||
                    expectedUpdateAction == 1 && row.UpdateAction == 0 &&
                    actual.ForeignKeys.Values.Any(sibling =>
                        sibling.ParentObjectId == row.ParentObjectId && sibling.PrincipalObjectId == row.PrincipalObjectId &&
                        !sibling.Disabled && !sibling.Untrusted && sibling.DeleteAction == 0 && sibling.UpdateAction == 1 &&
                        sibling.Columns.SequenceEqual(row.Columns, StringComparer.OrdinalIgnoreCase) &&
                        sibling.PrincipalColumns.SequenceEqual(row.PrincipalColumns, StringComparer.OrdinalIgnoreCase)));
                if (row is null || row.Disabled || row.Untrusted ||
                    row.DeleteAction != 0 || !validUpdateAction ||
                    !string.Equals(row.PrincipalTable, $"{principalSchema}.{principalTable}", StringComparison.OrdinalIgnoreCase) ||
                    !row.Columns.SequenceEqual(foreignKey.Properties.Select(Column), StringComparer.OrdinalIgnoreCase) ||
                    !row.PrincipalColumns.SequenceEqual(foreignKey.PrincipalKey.Properties.Select(property => property.GetColumnName(principalStore)!), StringComparer.OrdinalIgnoreCase))
                    invalid.Add($"foreign key {key}");
            }
            foreach (var check in entity.GetCheckConstraints())
            {
                var key = $"{tableKey}.{check.Name}";
                if (!checkedObjects.Add(key)) continue;
                // SQL Server rewrites equivalent IN/BETWEEN/NOT expressions in
                // check definitions. Text equality would falsely reject valid
                // deployed rules. Require the active model's named, enabled,
                // trusted constraint on the correct table; regression tests
                // exercise its business behavior with accepted/rejected data.
                if (!actual.Checks.TryGetValue(key, out var row) || row.Disabled || row.Untrusted)
                    invalid.Add($"check constraint {key}");
            }
        }

        // EF8 merges indexes sharing the same property list. This nonunique
        // lookup is deliberately SQL-managed beside the filtered unique index.
        const string lookup = "dbo.PlayAwardCategories.IX_PlayAwardCategories_PlayId";
        if (!actual.Indexes.TryGetValue(lookup, out var extra) || extra.Unique || extra.Disabled ||
            !extra.Columns.SequenceEqual(new[] { "PlayId" }, StringComparer.OrdinalIgnoreCase) ||
            extra.Descending.Any(value => value) || extra.Included.Count != 0 || !string.IsNullOrEmpty(extra.Sql))
            invalid.Add($"SQL-managed index {lookup}");
    }

    private static async Task<ModelRuleCatalog> ReadModelRulesAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT s.name + N'.' + t.name + N'.' + i.name, i.is_unique, i.filter_definition,
                   i.is_disabled, c.name, ic.is_included_column, ic.is_descending_key
            FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
            JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE i.name IS NOT NULL AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
            ORDER BY s.name, t.name, i.name, ic.is_included_column, ic.key_ordinal, ic.index_column_id;

            SELECT s.name + N'.' + t.name + N'.' + k.name, k.type, c.name,
                   s.name + N'.' + t.name, i.is_disabled, i.is_unique
            FROM sys.key_constraints k JOIN sys.tables t ON t.object_id = k.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.indexes i ON i.object_id = k.parent_object_id AND i.index_id = k.unique_index_id
            JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
            JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE ic.key_ordinal > 0 ORDER BY s.name, t.name, k.name, ic.key_ordinal;

            SELECT s.name + N'.' + t.name + N'.' + f.name, ps.name + N'.' + pt.name,
                   f.is_disabled, f.is_not_trusted, f.delete_referential_action, f.update_referential_action,
                   c.name, pc.name, f.parent_object_id, f.referenced_object_id
            FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id = f.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.tables pt ON pt.object_id = f.referenced_object_id
            JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
            JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = f.object_id
            JOIN sys.columns c ON c.object_id = fc.parent_object_id AND c.column_id = fc.parent_column_id
            JOIN sys.columns pc ON pc.object_id = fc.referenced_object_id AND pc.column_id = fc.referenced_column_id
            ORDER BY s.name, t.name, f.name, fc.constraint_column_id;

            SELECT s.name + N'.' + t.name + N'.' + c.name, c.definition, c.is_disabled, c.is_not_trusted
            FROM sys.check_constraints c JOIN sys.tables t ON t.object_id = c.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id;
            """;
        var result = new ModelRuleCatalog();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = reader.GetString(0);
            if (!result.Indexes.TryGetValue(key, out var row))
                result.Indexes[key] = row = new IndexRule(reader.GetBoolean(1), reader.IsDBNull(2) ? null : reader.GetString(2), reader.GetBoolean(3));
            if (reader.GetBoolean(5)) row.Included.Add(reader.GetString(4));
            else { row.Columns.Add(reader.GetString(4)); row.Descending.Add(reader.GetBoolean(6)); }
        }
        await reader.NextResultAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = reader.GetString(0);
            if (!result.Keys.TryGetValue(key, out var row))
                result.Keys[key] = row = new KeyRule(reader.GetString(3), reader.GetString(1) == "PK", reader.GetBoolean(4), reader.GetBoolean(5));
            row.Columns.Add(reader.GetString(2));
        }
        await reader.NextResultAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = reader.GetString(0);
            if (!result.ForeignKeys.TryGetValue(key, out var row))
                result.ForeignKeys[key] = row = new ForeignKeyRule(reader.GetString(1), reader.GetBoolean(2), reader.GetBoolean(3),
                    reader.GetByte(4), reader.GetByte(5), reader.GetInt32(8), reader.GetInt32(9));
            row.Columns.Add(reader.GetString(6)); row.PrincipalColumns.Add(reader.GetString(7));
        }
        await reader.NextResultAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result.Checks[reader.GetString(0)] = new CheckRule(reader.GetString(1), reader.GetBoolean(2), reader.GetBoolean(3));
        return result;
    }

    // SQL Server adds brackets/parentheses/spacing when persisting predicates.
    // Preserve quoted literals while normalizing those catalog decorations.
    private static string NormalizeSql(string? sql)
    {
        var result = new StringBuilder();
        var quoted = false;
        for (var index = 0; index < (sql?.Length ?? 0); index++)
        {
            var value = sql![index];
            if (value == '\'')
            {
                result.Append(value);
                if (quoted && index + 1 < sql.Length && sql[index + 1] == '\'') { result.Append(sql[++index]); continue; }
                quoted = !quoted;
            }
            else if (quoted) result.Append(value);
            else if (!char.IsWhiteSpace(value) && value is not ('(' or ')' or '[' or ']'))
            {
                if ((value is 'n' or 'N') && index + 1 < sql.Length && sql[index + 1] == '\'') continue;
                result.Append(char.ToUpperInvariant(value));
            }
        }
        return result.ToString();
    }

    private sealed class ModelRuleCatalog
    {
        public Dictionary<string, IndexRule> Indexes { get; } = new(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, KeyRule> Keys { get; } = new(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, ForeignKeyRule> ForeignKeys { get; } = new(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, CheckRule> Checks { get; } = new(StringComparer.OrdinalIgnoreCase);
    }
    private sealed record IndexRule(bool Unique, string? Sql, bool Disabled)
    {
        public List<string> Columns { get; } = [];
        public List<bool> Descending { get; } = [];
        public HashSet<string> Included { get; } = new(StringComparer.OrdinalIgnoreCase);
    }
    private sealed record KeyRule(string Table, bool Primary, bool Disabled, bool Unique)
    {
        public List<string> Columns { get; } = [];
    }
    private sealed record ForeignKeyRule(string PrincipalTable, bool Disabled, bool Untrusted,
        byte DeleteAction, byte UpdateAction, int ParentObjectId, int PrincipalObjectId)
    {
        public List<string> Columns { get; } = [];
        public List<string> PrincipalColumns { get; } = [];
    }
    private sealed record CheckRule(string Sql, bool Disabled, bool Untrusted);
}
