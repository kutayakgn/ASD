using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;

namespace YKBAfife.Data.Migrations;

public sealed class AfifeContextDesignTimeFactory : IDesignTimeDbContextFactory<AfifeContext>
{
    public AfifeContext CreateDbContext(string[] args)
    {
        var configuration = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: false)
            .AddEnvironmentVariables()
            .Build();

        var connectionString = configuration.GetConnectionString("AfifeConnectionString")
            ?? throw new InvalidOperationException(
                "Connection string 'AfifeConnectionString' was not found.");

        var options = new DbContextOptionsBuilder<AfifeContext>()
            .UseSqlServer(connectionString)
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>()
            .Options;

        return new AfifeContext(options);
    }
}