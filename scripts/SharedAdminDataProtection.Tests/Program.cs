using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Services.Authentication;

var connectionString = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connectionString)) throw new ArgumentException("Use the dedicated disposable key-sharing runner.");
var settings = new SqlConnectionStringBuilder(connectionString);
var allowedServer = Environment.GetEnvironmentVariable("AFIFE_TEST_SQL_SERVER") ?? @"(localdb)\MSSQLLocalDB";
if (!Regex.IsMatch(allowedServer, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
    !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeSharedAdminKeysTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, allowedServer, StringComparison.OrdinalIgnoreCase) ||
    !settings.IntegratedSecurity || settings.AttachDBFilename.Length != 0)
    throw new ArgumentException("Only the runner's GUID-suffixed integrated-authentication LocalDB is allowed.");
await new SharedKeyChecks(connectionString).RunAsync();

sealed class SharedKeyChecks(string connectionString)
{
    private int assertions;
    private const string Scheme = CookieAuthenticationDefaults.AuthenticationScheme;
    private const string Password = "Shared-node-fixture-İstanbul-9!";

    public async Task RunAsync()
    {
        await using (var context = new AfifeContext(new DbContextOptionsBuilder<AfifeContext>()
            .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options))
            await context.Database.MigrateAsync();
        // Exercise the real startup validator as well as migration execution.
        var startupConfiguration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:AfifeConnectionString"] = connectionString
        }).Build();
        var startupServices = new ServiceCollection();
        startupServices.AddDbContext<AfifeContext>(options => options.UseSqlServer(connectionString)
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>());
        await using (var startupProvider = startupServices.BuildServiceProvider())
            await new DatabaseMigrationHostedService(startupProvider.GetRequiredService<IServiceScopeFactory>(),
                startupConfiguration, NullLogger<DatabaseMigrationHostedService>.Instance).StartAsync(default);
        var hash = PasswordHashHelper.HashPassword(Password);
        await ExecuteAsync("""
            INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
            VALUES (NEWID(), N'Shared', N'Node', N'shared.node', @hash, N'shared.node@example.invalid', 1, 1, 1, 0);
            """, ("@hash", hash));
        var businessBefore = await BusinessSnapshotAsync();
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.SharedAdminDataProtectionKeys") == 0, "New key store starts empty.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.triggers WHERE name = N'TR_AdminAudit_dbo_SharedAdminDataProtectionKeys'") == 0,
            "Secret key XML has no full-row audit trigger.");

        using var nodeA = Node("node-a/release-one");
        using var nodeB = Node("node-b/different-release-path");
        Check(nodeA.GetRequiredService<IOptions<DataProtectionOptions>>().Value.ApplicationDiscriminator == SharedAdminDataProtectionExtensions.ApplicationName &&
              nodeB.GetRequiredService<IOptions<DataProtectionOptions>>().Value.ApplicationDiscriminator == SharedAdminDataProtectionExtensions.ApplicationName,
            "Nodes use the stable admin application discriminator across content roots.");
        var protectorA = nodeA.GetRequiredService<IDataProtectionProvider>().CreateProtector("shared-fixture");
        var protectorB = nodeB.GetRequiredService<IDataProtectionProvider>().CreateProtector("shared-fixture");
        var payloadA = protectorA.Protect("node-a fixture");
        Check(protectorB.Unprotect(payloadA) == "node-a fixture", "Node B decrypts node A payload.");
        Check(protectorA.Unprotect(protectorB.Protect("node-b fixture")) == "node-b fixture", "Node A decrypts node B payload.");
        var retainedKeys = await KeySnapshotAsync();
        Check(retainedKeys.Count > 0, "Framework keys were persisted to the shared DB.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.SharedAdminDataProtectionKeys WHERE [Xml] LIKE N'%DpapiXmlDecryptor%'") == 0,
            "Shared keys do not use a per-machine DPAPI decryptor.");

        var principal = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Name, "shared.node"), new Claim(ClaimTypes.Role, "Coordinator")
        }, Scheme));
        var ticket = new AuthenticationTicket(principal, new AuthenticationProperties
        {
            IsPersistent = true, IssuedUtc = DateTimeOffset.UtcNow, ExpiresUtc = DateTimeOffset.UtcNow.AddMinutes(10)
        }, Scheme);
        var formatA = nodeA.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(Scheme).TicketDataFormat;
        var formatB = nodeB.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(Scheme).TicketDataFormat;
        var cookie = formatA.Protect(ticket);
        Check(formatB.Unprotect(cookie)?.Principal.Identity?.Name == "shared.node", "Real cookie ticket format decrypts across nodes.");
        Check(formatA.Unprotect(formatB.Protect(ticket))?.Properties.IsPersistent == true, "Cookie ticket properties round-trip in both directions.");
        using (var restartedNode = Node("node-a/release-two"))
        {
            Check(restartedNode.GetRequiredService<IDataProtectionProvider>().CreateProtector("shared-fixture").Unprotect(payloadA) == "node-a fixture",
                "A fresh provider after deployment decrypts the previous payload.");
            Check(restartedNode.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(Scheme).TicketDataFormat.Unprotect(cookie)?.Principal.Identity?.Name == "shared.node",
                "A restarted provider with a new content root decrypts the previous auth cookie.");
        }
        AssertRetained(retainedKeys, await KeySnapshotAsync());

        var keyManager = nodeA.GetRequiredService<IKeyManager>();
        var rotation = keyManager.CreateNewKey(DateTimeOffset.UtcNow.AddDays(1), DateTimeOffset.UtcNow.AddDays(91));
        keyManager.RevokeKey(rotation.KeyId, "Disposable fixture revocation");
        var afterRotation = await KeySnapshotAsync();
        Check(afterRotation.Count >= retainedKeys.Count + 2, "Rotation and revocation append key-store records.");
        AssertRetained(retainedKeys, afterRotation);
        await RejectMutationAsync("UPDATE dbo.SharedAdminDataProtectionKeys SET FriendlyName = FriendlyName;");
        await RejectMutationAsync("DELETE FROM dbo.SharedAdminDataProtectionKeys;");
        AssertRetained(afterRotation, await KeySnapshotAsync());
        var tableIdentity = await NumberAsync("SELECT OBJECT_ID(N'dbo.SharedAdminDataProtectionKeys');");
        await using (var rollbackContext = new AfifeContext(new DbContextOptionsBuilder<AfifeContext>()
            .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
            .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options))
        {
            var migrations = rollbackContext.Database.GetMigrations().ToArray();
            var keyMigration = migrations.Single(item => item.Contains("_SharedAdminDataProtection_v_", StringComparison.Ordinal));
            var keyPosition = Array.IndexOf(migrations, keyMigration);
            Check(keyPosition > 0, "Shared key migration has a rollback target.");
            await rollbackContext.GetService<IMigrator>().MigrateAsync(migrations[keyPosition - 1]);
            Check(await NumberAsync("SELECT COUNT(*) FROM sys.tables WHERE name LIKE N'\\_\\_Archived\\_SharedAdminDataProtectionKeys\\_%' ESCAPE N'\\';") == 1,
                "Down retains the populated key store as one archived table.");
            Check(await NumberAsync("""
                SELECT COUNT(*) FROM sys.triggers tr JOIN sys.tables t ON t.object_id = tr.parent_id
                WHERE t.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\'
                  AND tr.name LIKE N'TR\_AdminAudit\_%' ESCAPE N'\';
                """) == 0, "Archived secret keys have no XML audit trigger after Down.");
            await rollbackContext.Database.MigrateAsync();
        }
        Check(await NumberAsync("SELECT OBJECT_ID(N'dbo.SharedAdminDataProtectionKeys');") == tableIdentity,
            "Re-Up restores the original table identity rather than copying/replacing key rows.");
        AssertRetained(afterRotation, await KeySnapshotAsync());
        using (var restoredNode = Node("restored/release-after-rollback"))
            Check(restoredNode.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(Scheme)
                .TicketDataFormat.Unprotect(cookie)?.Principal.Identity?.Name == "shared.node",
                "A fresh node decrypts the original cookie after populated-key Down/Up.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.AdminLogs WHERE TableName = N'SharedAdminDataProtectionKeys'") == 0,
            "Key generation, rotation, revocation and rejected writes never expose XML in AdminLogs.");
        AssertBusinessUnchanged(businessBefore, await BusinessSnapshotAsync());
        Check(PasswordHashHelper.VerifyPassword(Password, hash), "Password hash verification remains independent of shared cookie keys.");

        // Corrupt XML is appended only in this throwaway DB at the very end.
        // It must fail closed without silently replacing, repairing or ignoring it.
        await ExecuteAsync("INSERT dbo.SharedAdminDataProtectionKeys (Id, FriendlyName, [Xml], CreatedAtUtc, IsPublished) VALUES (NEWID(), N'malformed-fixture', N'<malformed', SYSUTCDATETIME(), 1);");
        var beforeCorruptRead = await KeySnapshotAsync();
        try
        {
            nodeB.GetRequiredService<SqlSharedAdminDataProtectionXmlRepository>().GetAllElements();
            throw new InvalidOperationException("Malformed XML was silently accepted.");
        }
        catch (CryptographicException error)
        {
            Check(!error.Message.Contains("<malformed", StringComparison.Ordinal) && error.InnerException is null,
                "Malformed XML fails with a generic non-secret diagnostic.");
        }
        using (var corruptNode = Node("fresh-node/invalid-key-ring"))
        {
            try
            {
                corruptNode.GetRequiredService<IDataProtectionProvider>().CreateProtector("shared-fixture").Protect("must fail");
                throw new InvalidOperationException("The framework silently replaced a malformed shared key ring.");
            }
            catch (CryptographicException) { assertions++; }
        }
        var afterCorruptRead = await KeySnapshotAsync();
        Check(afterCorruptRead.Count == beforeCorruptRead.Count, "Malformed key-ring reads create no replacement key rows.");
        AssertRetained(beforeCorruptRead, afterCorruptRead);
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.AdminLogs WHERE TableName = N'SharedAdminDataProtectionKeys'") == 0,
            "Malformed XML is never copied into the business audit.");
        AssertBusinessUnchanged(businessBefore, await BusinessSnapshotAsync());
        Console.WriteLine($"PASS: {assertions} shared admin Data Protection assertions: two content roots/nodes, real cookie formats, restart, rotation/revocation retention, populated Down/Up, append-only guards, no XML audit, malformed XML fails closed and business hashes/rows unchanged.");
    }

    private ServiceProvider Node(string contentRoot)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:AfifeConnectionString"] = connectionString
        }).Build();
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddSingleton<IHostEnvironment>(new NodeEnvironment(Path.GetFullPath(contentRoot)));
        services.AddAuthentication(Scheme).AddCookie(Scheme);
        services.AddSharedAdminDataProtection(configuration);
        return services.BuildServiceProvider();
    }
    private void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
        assertions++;
    }
    private void AssertRetained(Dictionary<Guid, string> before, Dictionary<Guid, string> after)
    {
        foreach (var key in before)
            Check(after.TryGetValue(key.Key, out var value) && string.Equals(value, key.Value, StringComparison.Ordinal),
                "Every previous key/revocation row remains byte-for-byte retained.");
    }
    private void AssertBusinessUnchanged(Dictionary<string, string> before, Dictionary<string, string> after)
    {
        foreach (var table in before)
            Check(after.TryGetValue(table.Key, out var value) && value == table.Value, $"Business rows changed in {table.Key}.");
    }
    private async Task RejectMutationAsync(string sql)
    {
        try { await ExecuteAsync(sql); throw new InvalidOperationException("Key-store mutation was accepted."); }
        catch (SqlException error) when (error.Number == 52750) { assertions++; }
    }
    private async Task<Dictionary<Guid, string>> KeySnapshotAsync()
    {
        await using var connection = new SqlConnection(connectionString); await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT Id, FriendlyName, [Xml], CreatedAtUtc, IsPublished FROM dbo.SharedAdminDataProtectionKeys;";
        await using var reader = await command.ExecuteReaderAsync();
        var rows = new Dictionary<Guid, string>();
        while (await reader.ReadAsync())
        {
            var stable = System.Text.Json.JsonSerializer.Serialize(new object?[]
            {
                reader.GetGuid(0), reader.IsDBNull(1) ? null : reader.GetString(1), reader.GetString(2), reader.GetDateTime(3), reader.GetBoolean(4)
            });
            rows.Add(reader.GetGuid(0), Convert.ToHexString(SHA256.HashData(Encoding.Unicode.GetBytes(stable))));
        }
        return rows;
    }
    private async Task<Dictionary<string, string>> BusinessSnapshotAsync()
    {
        await using var connection = new SqlConnection(connectionString); await connection.OpenAsync();
        var tables = new List<(string Name, string Keys)>();
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT t.name, STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(c.name)), N',') WITHIN GROUP (ORDER BY ic.key_ordinal)
                FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
                JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
                JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0
                JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                WHERE s.name = N'dbo' AND t.name NOT IN (N'SharedAdminDataProtectionKeys', N'AdminLogs', N'JuryLogs', N'UsersLog', N'__EFMigrationsHistory')
                GROUP BY t.name;
                """;
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync()) tables.Add((reader.GetString(0), reader.GetString(1)));
        }
        var snapshot = new Dictionary<string, string>();
        foreach (var table in tables)
        {
            await using var command = connection.CreateCommand();
            command.CommandText = $"SELECT * FROM dbo.[{table.Name.Replace("]", "]]")}] ORDER BY {table.Keys} FOR JSON PATH, INCLUDE_NULL_VALUES;";
            await using var reader = await command.ExecuteReaderAsync();
            var json = new StringBuilder(); while (await reader.ReadAsync()) json.Append(reader.GetString(0));
            snapshot[table.Name] = Convert.ToHexString(SHA256.HashData(Encoding.Unicode.GetBytes(json.ToString())));
        }
        return snapshot;
    }
    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = new SqlConnection(connectionString); await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; " + sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync();
    }
    private async Task<long> NumberAsync(string sql)
    {
        await using var connection = new SqlConnection(connectionString); await connection.OpenAsync();
        await using var command = connection.CreateCommand(); command.CommandText = sql;
        return Convert.ToInt64(await command.ExecuteScalarAsync());
    }
    private sealed class NodeEnvironment(string root) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Production;
        public string ApplicationName { get; set; } = "SharedKeyFixture";
        public string ContentRootPath { get; set; } = root;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
