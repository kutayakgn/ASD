using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace YKBAfife.Data.Migrations;

public sealed class DatabaseMigrationHostedService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<DatabaseMigrationHostedService> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var applyOnStartup = configuration.GetValue("DatabaseMigration:ApplyOnStartup", true);
        await using var scope = scopeFactory.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<AfifeContext>();
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
            else if (applyOnStartup)
            {
                logger.LogInformation("Applying {Count} migration(s): {Migrations}",
                    pending.Length, string.Join(", ", pending));
                await context.Database.MigrateAsync(cancellationToken);
                logger.LogInformation("Database migrations completed successfully.");
            }
            else
            {
                throw new InvalidOperationException(
                    "The database has pending migrations while startup migration is disabled: " +
                    string.Join(", ", pending) +
                    ". Apply the versioned EF migrations before application startup or enable startup migration.");
            }

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