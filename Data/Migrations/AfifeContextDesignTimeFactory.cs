using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;

namespace YKBAfife.Data.Migrations;

public sealed class AfifeContextDesignTimeFactory : IDesignTimeDbContextFactory<AfifeContext>
{
    public AfifeContext CreateDbContext(string[] args)
    {
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
            ?? "Development";
        var configuration = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var connectionString = configuration.GetConnectionString("AfifeAdmin")
            ?? throw new InvalidOperationException(
                "Connection string 'AfifeAdmin' was not found.");

        var options = new DbContextOptionsBuilder<AfifeContext>()
            .UseSqlServer(connectionString)
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>()
            .Options;

        return new AfifeContext(options);
    }
}