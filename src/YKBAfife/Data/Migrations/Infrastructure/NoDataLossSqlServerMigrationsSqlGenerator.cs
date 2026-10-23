using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Microsoft.EntityFrameworkCore.Update;
using Microsoft.EntityFrameworkCore.SqlServer.Migrations;
using Microsoft.EntityFrameworkCore.Storage;

namespace YKBAfife.Data.Migrations;

public sealed partial class NoDataLossSqlServerMigrationsSqlGenerator(
    MigrationsSqlGeneratorDependencies dependencies,
    ICommandBatchPreparer commandBatchPreparer)
    : SqlServerMigrationsSqlGenerator(dependencies, commandBatchPreparer)
{
    private const string ArchivedTableSourceProperty = "Afife:ArchivedTableSource";
    private const string ArchivedTableTimeProperty = "Afife:ArchivedTableAt";
    internal const string PreserveExistingColumnAnnotation = "Afife:PreserveExistingColumn";

    protected override void Generate(
        MigrationOperation operation,
        IModel? model,
        MigrationCommandListBuilder builder)
    {
        if (operation is DropColumnOperation dropColumn)
        {
            GenerateArchiveColumn(dropColumn, builder);
            return;
        }

        if (operation is AddColumnOperation addColumn)
        {
            GenerateAddOrRestoreColumn(addColumn, model, builder);
            return;
        }

        if (operation is DropTableOperation dropTable)
        {
            GenerateArchiveTable(dropTable, builder);
            return;
        }

        if (operation is CreateTableOperation createTable)
        {
            GenerateArchivedTableReplacementGuard(createTable, builder);
        }

        if (operation[MigrationSqlResources.ReviewedDataSafeSqlAnnotation] as bool? != true)
        {
            Validate(operation);
        }

        base.Generate(operation, model, builder);
    }

    private static void Validate(MigrationOperation operation)
    {
        if (operation is DeleteDataOperation)
        {
            throw new InvalidOperationException(
                $"Data-loss migration operation '{operation.GetType().Name}' is forbidden. " +
                "Use an additive expand/contract migration and preserve historical data.");
        }

        if (operation is AlterColumnOperation alter && alter.OldColumn is not null)
        {
            var safeStringWidening = IsSafeStringWidening(alter);
            var typeChanged = !string.Equals(
                alter.ColumnType, alter.OldColumn.ColumnType, StringComparison.OrdinalIgnoreCase);
            var lengthNarrowed = alter.MaxLength.HasValue &&
                (!alter.OldColumn.MaxLength.HasValue || alter.MaxLength < alter.OldColumn.MaxLength);
            var madeRequired = !alter.IsNullable && alter.OldColumn.IsNullable;

            if (((typeChanged || lengthNarrowed) && !safeStringWidening) || madeRequired)
            {
                throw new InvalidOperationException(
                    $"Potentially destructive alteration of '{alter.Table}.{alter.Name}' is forbidden " +
                    "without a reviewed, additive data migration.");
            }
        }

        if (operation is SqlOperation sql &&
            DestructiveSqlRegex().IsMatch(RemoveComments(sql.Sql)))
        {
            throw new InvalidOperationException(
                "Raw migration SQL contains DELETE FROM, TRUNCATE TABLE, DROP TABLE, or DROP COLUMN. " +
                "Physical data deletion is forbidden.");
        }
    }

    private static string RemoveComments(string sql) =>
        BlockCommentRegex().Replace(LineCommentRegex().Replace(sql, string.Empty), string.Empty);

    private static bool IsSafeStringWidening(AlterColumnOperation operation)
    {
        var oldType = VariableStringTypeRegex().Match(operation.OldColumn.ColumnType ?? string.Empty);
        var newType = VariableStringTypeRegex().Match(operation.ColumnType ?? string.Empty);
        if (!oldType.Success || !newType.Success ||
            !string.Equals(oldType.Groups[1].Value, newType.Groups[1].Value, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var oldLength = oldType.Groups[2].Value;
        var newLength = newType.Groups[2].Value;
        return string.Equals(newLength, "max", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(oldLength, "max", StringComparison.OrdinalIgnoreCase) &&
            int.Parse(newLength, System.Globalization.CultureInfo.InvariantCulture) >=
            int.Parse(oldLength, System.Globalization.CultureInfo.InvariantCulture);
    }

    private static void GenerateArchiveColumn(
        DropColumnOperation operation,
        MigrationCommandListBuilder builder)
    {
        builder.Append(RetainedColumnSql.Archive(operation.Schema ?? "dbo", operation.Table, operation.Name))
            .EndCommand();
    }

    private void GenerateAddOrRestoreColumn(
        AddColumnOperation operation,
        IModel? model,
        MigrationCommandListBuilder builder)
    {
        // Generate normal EF SQL once; only the archive-restoration branch differs.
        var normal = new MigrationCommandListBuilder(Dependencies);
        base.Generate(operation, model, normal);
        var schema = RetainedColumnSql.Literal(operation.Schema ?? "dbo");
        var table = RetainedColumnSql.Literal(operation.Table);
        var column = RetainedColumnSql.Literal(operation.Name);
        var qualified = $"{RetainedColumnSql.Delimited(operation.Schema ?? "dbo")}.{RetainedColumnSql.Delimited(operation.Table)}";
        var qualifiedLiteral = RetainedColumnSql.Literal(qualified);
        var desiredType = operation.ColumnType ?? GetColumnType(operation.Schema, operation.Table, operation.Name, operation, model)
            ?? throw new InvalidOperationException($"SQL type could not be resolved for {operation.Table}.{operation.Name}.");
        var normalizedType = desiredType.Replace("[", string.Empty).Replace("]", string.Empty).Replace(" ", string.Empty).ToLowerInvariant();
        normalizedType = normalizedType switch
        {
            "datetime2" or "datetimeoffset" or "time" => normalizedType + "(7)",
            "float" => "float(53)",
            _ => normalizedType
        };
        var defaultSql = operation.DefaultValueSql ??
            (operation.DefaultValue is null ? null : Dependencies.TypeMappingSource.GetMappingForValue(operation.DefaultValue).GenerateSqlLiteral(operation.DefaultValue));

        // Explicit opt-in for legacy schema adoption. Preserve an existing
        // column/value; hosted schema validation still checks its definition.
        // Unannotated historical operations keep their original behavior.
        var preserveExisting = operation[PreserveExistingColumnAnnotation] as bool? == true;
        if (preserveExisting)
            builder.AppendLine($"IF COL_LENGTH(N'{qualifiedLiteral}', N'{column}') IS NULL BEGIN");

        builder.Append($$"""
            DECLARE @restoreObjectId int = OBJECT_ID(N'{{qualifiedLiteral}}', N'U');
            DECLARE @restoreArchive sysname;
            SELECT TOP (1) @restoreArchive = columnRecord.name
            FROM sys.columns AS columnRecord
            INNER JOIN sys.extended_properties AS sourceProperty
              ON sourceProperty.class = 1 AND sourceProperty.major_id = columnRecord.object_id
             AND sourceProperty.minor_id = columnRecord.column_id AND sourceProperty.name = N'{{RetainedColumnSql.SourceProperty}}'
            LEFT JOIN sys.extended_properties AS timeProperty
              ON timeProperty.class = 1 AND timeProperty.major_id = columnRecord.object_id
             AND timeProperty.minor_id = columnRecord.column_id AND timeProperty.name = N'{{RetainedColumnSql.TimeProperty}}'
            WHERE columnRecord.object_id = @restoreObjectId AND CONVERT(nvarchar(128), sourceProperty.value) = N'{{column}}'
            ORDER BY CONVERT(nvarchar(33), timeProperty.value) DESC, columnRecord.column_id DESC;
            IF @restoreArchive IS NOT NULL AND COL_LENGTH(N'{{qualifiedLiteral}}', N'{{column}}') IS NULL
            BEGIN
                DECLARE @restoreType nvarchar(512), @restoreCollation sysname;
                SELECT @restoreType =
                    CASE WHEN typeRecord.is_user_defined = 1
                         THEN QUOTENAME(SCHEMA_NAME(typeRecord.schema_id)) + N'.' + QUOTENAME(typeRecord.name)
                         ELSE typeRecord.name +
                            CASE WHEN typeRecord.name IN (N'varchar', N'char', N'varbinary', N'binary')
                                 THEN N'(' + CASE WHEN columnRecord.max_length = -1 THEN N'max' ELSE CONVERT(nvarchar(10), columnRecord.max_length) END + N')'
                                 WHEN typeRecord.name IN (N'nvarchar', N'nchar')
                                 THEN N'(' + CASE WHEN columnRecord.max_length = -1 THEN N'max' ELSE CONVERT(nvarchar(10), columnRecord.max_length / 2) END + N')'
                                 WHEN typeRecord.name IN (N'decimal', N'numeric')
                                 THEN N'(' + CONVERT(nvarchar(10), columnRecord.precision) + N',' + CONVERT(nvarchar(10), columnRecord.scale) + N')'
                                 WHEN typeRecord.name IN (N'datetime2', N'datetimeoffset', N'time')
                                 THEN N'(' + CONVERT(nvarchar(10), columnRecord.scale) + N')'
                                 WHEN typeRecord.name = N'float' THEN N'(' + CONVERT(nvarchar(10), columnRecord.precision) + N')'
                                 ELSE N'' END END,
                       @restoreCollation = columnRecord.collation_name
                FROM sys.columns AS columnRecord
                INNER JOIN sys.types AS typeRecord ON typeRecord.user_type_id = columnRecord.user_type_id
                WHERE columnRecord.object_id = @restoreObjectId AND columnRecord.name = @restoreArchive;
                IF REPLACE(REPLACE(REPLACE(LOWER(@restoreType), N'[', N''), N']', N''), N' ', N'') <> N'{{RetainedColumnSql.Literal(normalizedType)}}'
                    THROW 51022, 'An archived column exists with another SQL type. Restore/backfill it explicitly in a reviewed migration instead of silently replacing its data.', 1;
            """);

        if (operation.ComputedColumnSql is not null || operation.IsRowVersion || operation["SqlServer:Identity"] is not null)
        {
            builder.Append("THROW 51023, 'Archived columns cannot be implicitly restored as identity, computed or rowversion columns.', 1;");
        }
        else
        {
            if (!operation.IsNullable)
            {
                builder.Append($$"""
                    DECLARE @restoreNullCount bigint;
                    DECLARE @restoreCountSql nvarchar(max) = N'SELECT @count = COUNT_BIG(*) FROM {{qualifiedLiteral}} WHERE ' + QUOTENAME(@restoreArchive) + N' IS NULL;';
                    EXEC sys.sp_executesql @restoreCountSql, N'@count bigint OUTPUT', @count = @restoreNullCount OUTPUT;
                    IF @restoreNullCount > 0
                        THROW 51024, 'Restoring a required archived column needs an explicit backfill for rows created while it was retired. Existing data has not been overwritten.', 1;
                    """);
            }
            if (operation.Collation is not null)
            {
                builder.Append($"IF ISNULL(@restoreCollation, N'') <> N'{RetainedColumnSql.Literal(operation.Collation)}' THROW 51025, 'Archived column collation differs; use a reviewed restoration migration.', 1;");
            }
            builder.Append($$"""
                DECLARE @restoreOriginal nvarchar(776) = N'{{qualifiedLiteral}}.' + QUOTENAME(@restoreArchive);
                EXEC sys.sp_rename @restoreOriginal, N'{{column}}', N'COLUMN';
                DECLARE @restoreAlterSql nvarchar(max) = N'ALTER TABLE {{qualifiedLiteral}} ALTER COLUMN {{RetainedColumnSql.Literal(RetainedColumnSql.Delimited(operation.Name))}} {{RetainedColumnSql.Literal(desiredType)}}' +
                    CASE WHEN @restoreCollation IS NULL THEN N'' ELSE N' COLLATE ' + @restoreCollation END + N' {{(operation.IsNullable ? "NULL" : "NOT NULL")}};';
                EXEC sys.sp_executesql @restoreAlterSql;
                EXEC sys.sp_dropextendedproperty @name = N'{{RetainedColumnSql.SourceProperty}}',
                    @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = N'{{table}}', @level2type = N'COLUMN', @level2name = N'{{column}}';
                EXEC sys.sp_dropextendedproperty @name = N'{{RetainedColumnSql.TimeProperty}}',
                    @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = N'{{table}}', @level2type = N'COLUMN', @level2name = N'{{column}}';
                """);
            if (defaultSql is not null)
            {
                builder.Append($"ALTER TABLE {qualified} ADD DEFAULT ({defaultSql}) FOR {RetainedColumnSql.Delimited(operation.Name)};");
            }
        }
        builder.AppendLine("END ELSE BEGIN");
        foreach (var command in normal.GetCommandList())
        {
            builder.AppendLine(command.CommandText);
        }
        builder.AppendLine("END;");
        if (preserveExisting) builder.AppendLine("END;");
        builder.EndCommand();
    }

    private static void GenerateArchiveTable(
        DropTableOperation operation,
        MigrationCommandListBuilder builder)
    {
        var schema = EscapeSqlLiteral(operation.Schema ?? "dbo");
        var table = EscapeSqlLiteral(operation.Name);
        var rawArchivePrefix = $"__Archived_{operation.Name}_";
        var archivePrefix = EscapeSqlLiteral(
            rawArchivePrefix[..Math.Min(113, rawArchivePrefix.Length)]);

        builder.Append($$"""
            IF OBJECT_ID(N'[{{schema}}].[{{table}}]', N'U') IS NOT NULL
            BEGIN
                DECLARE @archiveTable sysname = LEFT(
                    N'{{archivePrefix}}' +
                    CONVERT(char(8), SYSUTCDATETIME(), 112) +
                    REPLACE(CONVERT(char(8), SYSUTCDATETIME(), 108), N':', N''), 128);
                WHILE OBJECT_ID(QUOTENAME(N'{{schema}}') + N'.' + QUOTENAME(@archiveTable), N'U') IS NOT NULL
                    SET @archiveTable = LEFT(N'{{archivePrefix}}' +
                        REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N''), 128);

                DECLARE @archiveTableObject nvarchar(517) =
                    QUOTENAME(N'{{schema}}') + N'.' + QUOTENAME(N'{{table}}');
                EXEC sys.sp_rename @archiveTableObject, @archiveTable, N'OBJECT';
                DECLARE @archiveTableId int = OBJECT_ID(QUOTENAME(N'{{schema}}') + N'.' + QUOTENAME(@archiveTable), N'U');
                DECLARE @archiveTableAt nvarchar(33) = CONVERT(nvarchar(33), SYSUTCDATETIME(), 126);
                IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 1 AND major_id = @archiveTableId AND minor_id = 0 AND name = N'{{ArchivedTableSourceProperty}}')
                    EXEC sys.sp_updateextendedproperty @name = N'{{ArchivedTableSourceProperty}}', @value = N'{{table}}',
                        @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = @archiveTable;
                ELSE
                    EXEC sys.sp_addextendedproperty @name = N'{{ArchivedTableSourceProperty}}', @value = N'{{table}}',
                        @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = @archiveTable;
                IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 1 AND major_id = @archiveTableId AND minor_id = 0 AND name = N'{{ArchivedTableTimeProperty}}')
                    EXEC sys.sp_updateextendedproperty @name = N'{{ArchivedTableTimeProperty}}', @value = @archiveTableAt,
                        @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = @archiveTable;
                ELSE
                    EXEC sys.sp_addextendedproperty @name = N'{{ArchivedTableTimeProperty}}', @value = @archiveTableAt,
                        @level0type = N'SCHEMA', @level0name = N'{{schema}}', @level1type = N'TABLE', @level1name = @archiveTable;
            END;
            """)
            .EndCommand();
    }

    private static void GenerateArchivedTableReplacementGuard(
        CreateTableOperation operation,
        MigrationCommandListBuilder builder)
    {
        var schema = EscapeSqlLiteral(operation.Schema ?? "dbo");
        var table = EscapeSqlLiteral(operation.Name);
        var rawPrefix = $"__Archived_{operation.Name}_";
        var prefix = EscapeSqlLiteral(rawPrefix[..Math.Min(113, rawPrefix.Length)]);
        // Whole-table rollback involves all retained PK/FK/index/trigger names.
        // A reviewed RenameTable restoration is required; never substitute an
        // empty table or blindly skip a differently-defined retained constraint.
        builder.Append($$"""
            IF EXISTS
            (
                SELECT 1 FROM sys.tables AS retainedTable
                LEFT JOIN sys.extended_properties AS sourceProperty
                  ON sourceProperty.class = 1 AND sourceProperty.major_id = retainedTable.object_id
                 AND sourceProperty.minor_id = 0 AND sourceProperty.name = N'{{ArchivedTableSourceProperty}}'
                WHERE retainedTable.schema_id = SCHEMA_ID(N'{{schema}}')
                  AND
                  (
                      CONVERT(nvarchar(128), sourceProperty.value) = N'{{table}}'
                      OR LEFT(retainedTable.name, LEN(N'{{prefix}}')) = N'{{prefix}}'
                  )
            )
                THROW 51026, 'An archived copy of this table exists. Restore it with a reviewed RenameTable migration and reconcile retained keys, indexes and foreign keys; an empty replacement is forbidden.', 1;
            """).EndCommand();
    }

    private static string EscapeSqlLiteral(string value) => value.Replace("'", "''");

    [GeneratedRegex(@"^\s*(nvarchar|varchar)\s*\(\s*(max|[0-9]+)\s*\)\s*$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex VariableStringTypeRegex();

    [GeneratedRegex(@"\b(?:DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DestructiveSqlRegex();

    [GeneratedRegex(@"--.*?$", RegexOptions.Multiline)]
    private static partial Regex LineCommentRegex();

    [GeneratedRegex(@"/\*.*?\*/", RegexOptions.Singleline)]
    private static partial Regex BlockCommentRegex();
}
