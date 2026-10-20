namespace YKBAfife.Data.Migrations;

/// <summary>
/// Removing an EF/legacy column means retiring its name, never deleting its values.
/// The same-table archive is nullable and has no default, so new rows do not need it.
/// SQL Server metadata retains the original type, collation and row correspondence.
/// </summary>
internal static class RetainedColumnSql
{
    internal const string SourceProperty = "Afife:ArchivedColumnSource";
    internal const string TimeProperty = "Afife:ArchivedColumnAt";

    internal static string Archive(string schema, string table, string column)
    {
        var schemaLiteral = Literal(schema);
        var tableLiteral = Literal(table);
        var columnLiteral = Literal(column);
        var qualified = $"{Delimited(schema)}.{Delimited(table)}";
        var qualifiedLiteral = Literal(qualified);
        var prefix = Literal($"__Archived_{column}_"[..Math.Min(90, column.Length + 12)]);

        return $$"""
            DECLARE @retainedObjectId int = OBJECT_ID(N'{{qualifiedLiteral}}', N'U');
            DECLARE @retainedColumnId int = COLUMNPROPERTY(@retainedObjectId, N'{{columnLiteral}}', 'ColumnId');
            IF @retainedColumnId IS NOT NULL
            BEGIN
                IF EXISTS
                (
                    SELECT 1 FROM sys.index_columns
                    WHERE object_id = @retainedObjectId AND column_id = @retainedColumnId
                ) OR EXISTS
                (
                    SELECT 1 FROM sys.foreign_key_columns
                    WHERE (parent_object_id = @retainedObjectId AND parent_column_id = @retainedColumnId)
                       OR (referenced_object_id = @retainedObjectId AND referenced_column_id = @retainedColumnId)
                ) OR EXISTS
                (
                    SELECT 1 FROM sys.check_constraints
                    WHERE parent_object_id = @retainedObjectId AND parent_column_id = @retainedColumnId
                ) OR EXISTS
                (
                    SELECT 1 FROM sys.sql_expression_dependencies AS dependency
                    LEFT JOIN sys.default_constraints AS defaultConstraint
                      ON defaultConstraint.object_id = dependency.referencing_id
                    WHERE dependency.referenced_id = @retainedObjectId
                      AND dependency.referenced_minor_id = @retainedColumnId
                      AND defaultConstraint.object_id IS NULL
                )
                    THROW 51020, 'Column retirement requires a reviewed migration for its index, key, foreign key, check, computed-column or SQL-module dependencies.', 1;

                DECLARE @retainedType nvarchar(512), @retainedNullable bit,
                        @retainedCollation sysname, @retainedUnsupported bit;
                SELECT @retainedType =
                    CASE WHEN typeRecord.is_user_defined = 1
                         THEN QUOTENAME(SCHEMA_NAME(typeRecord.schema_id)) + N'.' + QUOTENAME(typeRecord.name)
                         ELSE QUOTENAME(typeRecord.name) +
                            CASE WHEN typeRecord.name IN (N'varchar', N'char', N'varbinary', N'binary')
                                 THEN N'(' + CASE WHEN columnRecord.max_length = -1 THEN N'max'
                                                 ELSE CONVERT(nvarchar(10), columnRecord.max_length) END + N')'
                                 WHEN typeRecord.name IN (N'nvarchar', N'nchar')
                                 THEN N'(' + CASE WHEN columnRecord.max_length = -1 THEN N'max'
                                                 ELSE CONVERT(nvarchar(10), columnRecord.max_length / 2) END + N')'
                                 WHEN typeRecord.name IN (N'decimal', N'numeric')
                                 THEN N'(' + CONVERT(nvarchar(10), columnRecord.precision) + N',' + CONVERT(nvarchar(10), columnRecord.scale) + N')'
                                 WHEN typeRecord.name IN (N'datetime2', N'datetimeoffset', N'time')
                                 THEN N'(' + CONVERT(nvarchar(10), columnRecord.scale) + N')'
                                 WHEN typeRecord.name = N'float'
                                 THEN N'(' + CONVERT(nvarchar(10), columnRecord.precision) + N')'
                                 ELSE N'' END END,
                       @retainedNullable = columnRecord.is_nullable,
                       @retainedCollation = columnRecord.collation_name,
                       @retainedUnsupported = CONVERT(bit, CASE
                           WHEN columnRecord.is_identity = 1 OR columnRecord.is_computed = 1
                             OR columnRecord.generated_always_type <> 0 OR columnRecord.is_filestream = 1
                             OR typeRecord.name IN (N'timestamp', N'rowversion')
                             OR typeRecord.is_assembly_type = 1 THEN 1 ELSE 0 END)
                FROM sys.columns AS columnRecord
                INNER JOIN sys.types AS typeRecord ON typeRecord.user_type_id = columnRecord.user_type_id
                WHERE columnRecord.object_id = @retainedObjectId AND columnRecord.column_id = @retainedColumnId;

                IF @retainedUnsupported = 1
                    THROW 51021, 'Identity, computed, generated, FILESTREAM, rowversion or CLR columns need an explicitly reviewed data-retention migration.', 1;

                DECLARE @retainedDefault sysname =
                (
                    SELECT name FROM sys.default_constraints
                    WHERE parent_object_id = @retainedObjectId AND parent_column_id = @retainedColumnId
                );
                DECLARE @retainedSql nvarchar(max);
                IF @retainedDefault IS NOT NULL
                BEGIN
                    SET @retainedSql = N'ALTER TABLE {{qualifiedLiteral}} DROP CONSTRAINT ' + QUOTENAME(@retainedDefault) + N';';
                    EXEC sys.sp_executesql @retainedSql;
                END;
                IF @retainedNullable = 0
                BEGIN
                    SET @retainedSql = N'ALTER TABLE {{qualifiedLiteral}} ALTER COLUMN {{Literal(Delimited(column))}} ' +
                        @retainedType + CASE WHEN @retainedCollation IS NULL THEN N''
                                            ELSE N' COLLATE ' + @retainedCollation END + N' NULL;';
                    EXEC sys.sp_executesql @retainedSql;
                END;

                DECLARE @retainedArchive sysname = LEFT(N'{{prefix}}' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N''), 128);
                DECLARE @retainedOriginal nvarchar(776) = N'{{qualifiedLiteral}}.' + QUOTENAME(N'{{columnLiteral}}');
                EXEC sys.sp_rename @retainedOriginal, @retainedArchive, N'COLUMN';
                DECLARE @retainedAt nvarchar(33) = CONVERT(nvarchar(33), SYSUTCDATETIME(), 126);
                EXEC sys.sp_addextendedproperty @name = N'{{SourceProperty}}', @value = N'{{columnLiteral}}',
                    @level0type = N'SCHEMA', @level0name = N'{{schemaLiteral}}',
                    @level1type = N'TABLE', @level1name = N'{{tableLiteral}}',
                    @level2type = N'COLUMN', @level2name = @retainedArchive;
                EXEC sys.sp_addextendedproperty @name = N'{{TimeProperty}}', @value = @retainedAt,
                    @level0type = N'SCHEMA', @level0name = N'{{schemaLiteral}}',
                    @level1type = N'TABLE', @level1name = N'{{tableLiteral}}',
                    @level2type = N'COLUMN', @level2name = @retainedArchive;
            END;
            """;
    }

    internal static string Delimited(string identifier) => $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";
    internal static string Literal(string value) => value.Replace("'", "''", StringComparison.Ordinal);
}
