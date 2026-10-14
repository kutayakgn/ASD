using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Microsoft.EntityFrameworkCore.Update;
using Microsoft.EntityFrameworkCore.SqlServer.Migrations;

namespace YKBAfife.Data.Migrations;

public sealed partial class NoDataLossSqlServerMigrationsSqlGenerator(
    MigrationsSqlGeneratorDependencies dependencies,
    ICommandBatchPreparer commandBatchPreparer)
    : SqlServerMigrationsSqlGenerator(dependencies, commandBatchPreparer)
{
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

        if (operation is DropTableOperation dropTable)
        {
            GenerateArchiveTable(dropTable, builder);
            return;
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
            var typeChanged = !string.Equals(
                alter.ColumnType, alter.OldColumn.ColumnType, StringComparison.OrdinalIgnoreCase);
            var lengthNarrowed = alter.MaxLength.HasValue &&
                (!alter.OldColumn.MaxLength.HasValue || alter.MaxLength < alter.OldColumn.MaxLength);
            var madeRequired = !alter.IsNullable && alter.OldColumn.IsNullable;

            if (typeChanged || lengthNarrowed || madeRequired)
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

    private static void GenerateArchiveColumn(
        DropColumnOperation operation,
        MigrationCommandListBuilder builder)
    {
        var schema = EscapeSqlLiteral(operation.Schema ?? "dbo");
        var table = EscapeSqlLiteral(operation.Table);
        var column = EscapeSqlLiteral(operation.Name);
        var rawArchivePrefix = $"__Archived_{operation.Name}_";
        var archivePrefix = EscapeSqlLiteral(
            rawArchivePrefix[..Math.Min(113, rawArchivePrefix.Length)]);

        builder.Append($$"""
            IF COL_LENGTH(N'[{{schema}}].[{{table}}]', N'{{column}}') IS NOT NULL
            BEGIN
                DECLARE @archiveColumn sysname = LEFT(
                    N'{{archivePrefix}}' +
                    CONVERT(char(8), SYSUTCDATETIME(), 112) +
                    REPLACE(CONVERT(char(8), SYSUTCDATETIME(), 108), N':', N''), 128);
                WHILE COL_LENGTH(N'[{{schema}}].[{{table}}]', @archiveColumn) IS NOT NULL
                    SET @archiveColumn = LEFT(N'{{archivePrefix}}' +
                        REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N''), 128);

                DECLARE @archiveColumnObject nvarchar(776) =
                    QUOTENAME(N'{{schema}}') + N'.' + QUOTENAME(N'{{table}}') +
                    N'.' + QUOTENAME(N'{{column}}');
                EXEC sys.sp_rename @archiveColumnObject, @archiveColumn, N'COLUMN';
            END;
            """)
            .EndCommand();
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
            END;
            """)
            .EndCommand();
    }

    private static string EscapeSqlLiteral(string value) => value.Replace("'", "''");

    [GeneratedRegex(@"\b(?:DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DestructiveSqlRegex();

    [GeneratedRegex(@"--.*?$", RegexOptions.Multiline)]
    private static partial Regex LineCommentRegex();

    [GeneratedRegex(@"/\*.*?\*/", RegexOptions.Singleline)]
    private static partial Regex BlockCommentRegex();
}
