using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace YKBAfife.Data.Migrations;

/// <summary>
/// Retires only the legacy columns explicitly listed in ColumnsToDrop. Values
/// remain in nullable __Archived_* columns on the same rows, without defaults.
/// This code-controlled list runs idempotently after EF migrations during deploy.
/// </summary>
internal static class LegacyColumnCleanupRunner
{
    // Add one line here for each legacy column to remove in the next deploy.
    private static readonly LegacyColumnTarget[] ColumnsToDrop =
    [
        new("dbo", "Users", "Photo"),
        new("dbo", "Announcements", "BackgroundImage"),
        new("dbo", "Announcements", "Image"),
        new("dbo", "PlayAwardCategories", "Photo"),
        new("dbo", "PlayAwardCategories", "IsOld")
    ];

    public static async Task RunAsync(
        AfifeContext context,
        SqlConnection connection,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        var cleanupPlan = new List<LegacyColumnTarget>();
        foreach (var target in ColumnsToDrop)
        {
            EnsureColumnIsNotMapped(context, target);
            var state = await ReadColumnStateAsync(connection, target, cancellationToken);
            if (!state.Exists)
            {
                continue;
            }

            if (state.HasBlockingDependency)
            {
                throw new InvalidOperationException(
                    $"Legacy column {target.Schema}.{target.Table}.{target.Column} has an index, " +
                    "key, foreign key, check constraint, or computed-column dependency. " +
                    "Remove that dependency in a reviewed code change before retiring the column.");
            }

            logger.LogWarning(
                "Legacy column {Schema}.{Table}.{Column} will be archived; " +
                "values from {NonNullCount} row(s) will be retained on the same rows.",
                target.Schema, target.Table, target.Column, state.NonNullCount);
            cleanupPlan.Add(target);
        }

        if (cleanupPlan.Count == 0)
        {
            return;
        }

        await ArchiveColumnsAsync(connection, cleanupPlan, cancellationToken);
        foreach (var target in cleanupPlan)
        {
            logger.LogInformation(
                "Legacy column {Schema}.{Table}.{Column} was retired; " +
                "its data is recoverable from its __Archived_* column.",
                target.Schema, target.Table, target.Column);
        }
    }

    private static void EnsureColumnIsNotMapped(AfifeContext context, LegacyColumnTarget target)
    {
        var mapped = context.Model.GetRelationalModel().Tables.Any(table =>
            string.Equals(table.Schema ?? "dbo", target.Schema, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(table.Name, target.Table, StringComparison.OrdinalIgnoreCase) &&
            table.Columns.Any(column =>
                string.Equals(column.Name, target.Column, StringComparison.OrdinalIgnoreCase)));

        if (mapped)
        {
            throw new InvalidOperationException(
                $"Refusing to remove {target.Schema}.{target.Table}.{target.Column}: " +
                "the column is still mapped by the current EF model.");
        }
    }

    private static async Task<LegacyColumnState> ReadColumnStateAsync(
        SqlConnection connection,
        LegacyColumnTarget target,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = $"""
            DECLARE @objectId int = OBJECT_ID(@qualifiedTable, N'U');
            DECLARE @columnId int =
                CASE WHEN @objectId IS NULL THEN NULL
                     ELSE COLUMNPROPERTY(@objectId, @column, 'ColumnId') END;

            SELECT
                CONVERT(bit, CASE WHEN @columnId IS NULL THEN 0 ELSE 1 END),
                CONVERT(bit, CASE WHEN @columnId IS NULL THEN 0
                    WHEN EXISTS
                    (
                        SELECT 1 FROM sys.index_columns
                        WHERE object_id = @objectId AND column_id = @columnId
                    ) OR EXISTS
                    (
                        SELECT 1 FROM sys.foreign_key_columns
                        WHERE (parent_object_id = @objectId AND parent_column_id = @columnId)
                           OR (referenced_object_id = @objectId AND referenced_column_id = @columnId)
                    ) OR EXISTS
                    (
                        SELECT 1 FROM sys.check_constraints
                        WHERE parent_object_id = @objectId AND parent_column_id = @columnId
                    ) OR EXISTS
                    (
                        SELECT 1 FROM sys.computed_columns
                        WHERE object_id = @objectId
                          AND definition LIKE N'%' + QUOTENAME(@column) + N'%'
                    ) THEN 1 ELSE 0 END);

            IF @columnId IS NOT NULL
                EXEC sys.sp_executesql
                    N'SELECT @count = COUNT_BIG(*) FROM {Delimited(target.Schema)}.{Delimited(target.Table)} WHERE {Delimited(target.Column)} IS NOT NULL;',
                    N'@count bigint OUTPUT', @count = @nonNullCount OUTPUT;
            """;
        command.Parameters.Add(new SqlParameter("@qualifiedTable", SqlDbType.NVarChar, 517)
        {
            Value = $"{Delimited(target.Schema)}.{Delimited(target.Table)}"
        });
        command.Parameters.Add(new SqlParameter("@column", SqlDbType.NVarChar, 128)
        {
            Value = target.Column
        });
        var countParameter = command.Parameters.Add("@nonNullCount", SqlDbType.BigInt);
        countParameter.Direction = ParameterDirection.InputOutput;
        countParameter.Value = 0L;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        await reader.ReadAsync(cancellationToken);
        var exists = reader.GetBoolean(0);
        var hasBlockingDependency = reader.GetBoolean(1);
        await reader.CloseAsync();

        return new LegacyColumnState(
            exists,
            hasBlockingDependency,
            Convert.ToInt64(countParameter.Value));
    }

    private static async Task ArchiveColumnsAsync(
        SqlConnection connection,
        IReadOnlyCollection<LegacyColumnTarget> targets,
        CancellationToken cancellationToken)
    {
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            foreach (var target in targets)
            {
                await using var command = connection.CreateCommand();
                command.Transaction = transaction;
                command.CommandText = RetainedColumnSql.Archive(target.Schema, target.Table, target.Column);
                await command.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static string Delimited(string identifier) =>
        $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";

    private sealed record LegacyColumnTarget(string Schema, string Table, string Column);
    private sealed record LegacyColumnState(bool Exists, bool HasBlockingDependency, long NonNullCount);
}
