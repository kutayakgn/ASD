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
        if (operation[MigrationSqlResources.ReviewedDataSafeSqlAnnotation] as bool? != true)
        {
            Validate(operation);
        }

        base.Generate(operation, model, builder);
    }

    private static void Validate(MigrationOperation operation)
    {
        if (operation is DropTableOperation or DropColumnOperation or DeleteDataOperation)
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

    [GeneratedRegex(@"\b(?:DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex DestructiveSqlRegex();

    [GeneratedRegex(@"--.*?$", RegexOptions.Multiline)]
    private static partial Regex LineCommentRegex();

    [GeneratedRegex(@"/\*.*?\*/", RegexOptions.Singleline)]
    private static partial Regex BlockCommentRegex();
}