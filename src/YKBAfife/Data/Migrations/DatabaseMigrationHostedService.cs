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
            var pending = (await context.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
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
