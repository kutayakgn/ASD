using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace YKBAfife.Data.Migrations;

public sealed class DatabaseMigrationHostedService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<DatabaseMigrationHostedService> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<AfifeContext>();
        var migrator = context.GetService<IMigrator>();
        var connection = (SqlConnection)context.Database.GetDbConnection();
        await connection.OpenAsync(cancellationToken);

        var timeout = configuration.GetValue("DatabaseMigration:LockTimeoutMilliseconds", 120000);
        await AcquireLockAsync(connection, timeout, cancellationToken);
        try
        {
            var known = context.Database.GetMigrations().ToArray();
            var applied = (await context.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
            var pending = (await context.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
            EnsureMigrationHistoryIsSafe(known, applied, pending);

            if (pending.Length == 0)
            {
                logger.LogInformation("Database schema is up to date.");
            }
            else
            {
                logger.LogInformation("Applying {Count} migration(s): {Migrations}",
                    pending.Length, string.Join(", ", pending));

                foreach (var migration in pending)
                {
                    logger.LogInformation("Applying database migration {Migration}.", migration);
                    try
                    {
                        await migrator.MigrateAsync(migration, cancellationToken);
                    }
                    catch (Exception exception)
                    {
                        logger.LogError(exception,
                            "Database migration {Migration} failed.", migration);
                        throw;
                    }
                }

                logger.LogInformation("Database migrations completed successfully.");
            }

            var appliedAfterUpdate =
                (await context.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
            EnsureMigrationHistoryIsSafe(known, appliedAfterUpdate, []);

            await LegacyColumnCleanupRunner.RunAsync(
                context, connection, logger, cancellationToken);

            await DatabaseSchemaValidator.ValidateAsync(context, connection, cancellationToken);
            logger.LogInformation("Database schema validation completed successfully.");
        }
        finally
        {
            await ReleaseLockAsync(connection, cancellationToken);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private static void EnsureMigrationHistoryIsSafe(
        IReadOnlyCollection<string> known,
        IReadOnlyCollection<string> applied,
        IReadOnlyCollection<string> pending)
    {
        var unknownApplied = applied
            .Except(known, StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (unknownApplied.Length == 0)
        {
            return;
        }

        var baselineIsPending = pending.Any(x =>
            x.EndsWith("_InitialBaseline_v_20260827", StringComparison.OrdinalIgnoreCase));
        if (baselineIsPending)
        {
            // First deployment of the squashed baseline. Its Up method converges the
            // schema and replaces only the obsolete EF history rows.
            return;
        }

        throw new InvalidOperationException(
            "Database migration history is ahead of the deployed application. " +
            "Applied migration(s) missing from this build: " +
            string.Join(", ", unknownApplied) + ". " +
            "A migration cannot be removed from source before its Down migration is " +
            "applied. Restore that migration, run 'dotnet ef database update <previous>', " +
            "then run 'dotnet ef migrations remove' and deploy again.");
    }

    private static async Task AcquireLockAsync(
        SqlConnection connection,
        int timeout,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = """
            DECLARE @result int;
            EXEC @result = sys.sp_getapplock
                @Resource = N'YKBAfife:EFCoreMigrations',
                @LockMode = N'Exclusive',
                @LockOwner = N'Session',
                @LockTimeout = @timeout;
            IF @result < 0
                THROW 51000, 'Database migration lock could not be acquired.', 1;
            """;
        command.Parameters.Add(new SqlParameter("@timeout", SqlDbType.Int) { Value = timeout });
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task ReleaseLockAsync(
        SqlConnection connection,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = """
            EXEC sys.sp_releaseapplock
                @Resource = N'YKBAfife:EFCoreMigrations',
                @LockOwner = N'Session';
            """;
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
