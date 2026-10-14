using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Helpers;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Reports;

// Never obtain an application connection implicitly. The runner owns this GUID-suffixed database.
var connection = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connection))
    throw new ArgumentException("Pass --connection for the runner's disposable jury home page settings database.");
var settings = new SqlConnectionStringBuilder(connection);
if (!Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeHomePageSettingsTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, @"(localdb)\MSSQLLocalDB", StringComparison.OrdinalIgnoreCase) ||
    !settings.IntegratedSecurity)
    throw new ArgumentException("Only the dedicated GUID-suffixed disposable LocalDB is allowed.");
await new RegressionChecks(connection).RunAsync();

sealed class RegressionChecks(string connection)
{
    private int assertions;
    private Guid adminId;
    private string previousMigration = "";
    private string settingsMigration = "";
    private static IReadOnlyList<JuryHomePageTableDefinition> Definitions => JuryHomePageTableSettings.Definitions;
    private AfifeContext Context() => new(new DbContextOptionsBuilder<AfifeContext>()
        .UseSqlServer(connection, sql => sql.CommandTimeout(180))
        .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options);

    public async Task RunAsync()
    {
        await using (var context = Context())
        {
            var migrations = context.Database.GetMigrations().ToArray();
            var baseline = migrations.Single(id => id.EndsWith("_InitialBaseline_v_20260827", StringComparison.Ordinal));
            settingsMigration = migrations.Single(id => id.Contains("_JuryHomePageTableSettings_v_", StringComparison.Ordinal));
            var position = Array.IndexOf(migrations, settingsMigration);
            Check(position > 0, "New settings are introduced by an additive versioned migration.");
            previousMigration = migrations[position - 1];
            await context.GetService<IMigrator>().MigrateAsync(baseline);
            Check(await NumberAsync("SELECT COUNT(*) FROM dbo.Configs WHERE ConfigName LIKE N'HomePage%TableEnabled'") == 0,
                "Immutable baseline does not acquire new settings retroactively.");
            Check(await Controller(context).UpdateJuryHomePageTableStatus(JuryHomePageTableSettings.JuryTable, true, default) is ChallengeResult,
                "A request without a user identity does not mutate an old database.");
            await SeedAdminAsync();
            Check(await Controller(context).UpdateJuryHomePageTableStatus(JuryHomePageTableSettings.JuryTable, true, default) is NotFoundResult,
                "A known but not yet deployed config returns not found instead of being created by an endpoint request.");
            await context.Database.MigrateAsync();
        }
        await CheckInitialRowsAsync();
        await TestEndpointAsync();
        await TestFactoryAsync();
        await TestDatabaseGuardsAsync();
        await TestReplayAsync();
        await TestRollbackAndLegacyIdAsync();
        Console.WriteLine($"PASS: {assertions} jury home page settings regression assertions using actual controller, factory and migrations.");
    }

    private async Task CheckInitialRowsAsync()
    {
        Check(Definitions.Select(definition => definition.Name).SequenceEqual(new[]
        {
            "HomePageJuryTableEnabled", "HomePageMissionTableEnabled",
            "HomePageMostWatchedTableEnabled", "HomePageLeastWatchedTableEnabled"
        }), "Integration keys have stable canonical spelling and order.");
        Check(Definitions.Select(definition => definition.Title).Distinct().Count() == 4,
            "Four individually labelled table switches are defined.");
        await using var context = Context();
        var names = Definitions.Select(definition => definition.Name).ToArray();
        var rows = await context.Configs.AsNoTracking().Where(row => names.Contains(row.ConfigName)).ToArrayAsync();
        Check(rows.Length == 4, "Blank database migration inserts exactly four settings.");
        Check(rows.All(row => row.ConfigValue == "true" && row.IsPublished), "All new fixed settings default to enabled and published.");
        Check(rows.Select(row => row.Id).Distinct().Count() == 4 && rows.All(row => row.Id != Guid.Empty),
            "Every fixed setting has a distinct nonempty ID.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Configs') AND name = N'UX_Configs_JuryHomePageTableName' AND is_unique = 1 AND has_filter = 1") == 1,
            "Fixed setting names have their own filtered unique index.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Configs') AND name = N'CK_Configs_JuryHomePageTableValue' AND is_disabled = 0 AND is_not_trusted = 0") == 1,
            "Canonical values and fixed publication are enforced by a trusted check constraint.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.triggers WHERE object_id = OBJECT_ID(N'dbo.TR_Configs_ProtectJuryHomePageSettings') AND is_disabled = 0") == 1,
            "Fixed name and identity protection is deployed.");
        Console.WriteLine("PASS: blank database defaults, stable keys and deployed protections.");
    }

    private async Task SeedAdminAsync()
    {
        adminId = Guid.NewGuid();
        await ExecuteAsync("""
            INSERT INTO dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
            VALUES (@id, N'HomePage', N'Regression', @username, N'not-a-real-hash', @email, 1, 1, 1, 0)
            """, ("@id", adminId), ("@username", "admin." + adminId.ToString("N")[..12]), ("@email", adminId + "@example.invalid"));
    }

    private async Task TestEndpointAsync()
    {
        var method = typeof(ManagementController).GetMethod(nameof(ManagementController.UpdateJuryHomePageTableStatus))!;
        Check(method.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>().Any(attribute => attribute.Roles == "Coordinator"),
            "Only coordinators are authorized to change integration settings.");
        Check(method.IsDefined(typeof(ValidateAntiForgeryTokenAttribute), true) && method.IsDefined(typeof(AdminMutationAuditAttribute), true),
            "Endpoint retains antiforgery and mutation audit filters.");
        foreach (var definition in Definitions)
        {
            var before = await RowsSnapshotAsync();
            await using var context = Context();
            var result = await Controller(context).UpdateJuryHomePageTableStatus(definition.Name, false, default);
            Check(IsSuccess(result, false), $"{definition.Name} can be switched off immediately.");
            var changed = await context.Configs.AsNoTracking().SingleAsync(row => row.ConfigName == definition.Name);
            Check(changed.ConfigValue == "false" && changed.UpdatedBy == adminId,
                "Real endpoint persists canonical lowercase value and editing user.");
            Check(await RowsSnapshotAsync() != before, "Changed switch is persisted before a separate save action.");
            var log = await context.AdminLogs.AsNoTracking().Where(row => row.TableName == "Configs" &&
                row.OperationType == "Update" && row.OldValues != null && row.NewValues != null)
                .OrderByDescending(row => row.OccurredAt).ToArrayAsync();
            Check(log.Any(row => HasConfigValue(row.OldValues!, definition.Name, "true") &&
                HasConfigValue(row.NewValues!, definition.Name, "false")), "Database audit captures the old and new switch value.");
            var noOpSnapshot = await RowsSnapshotAsync();
            var auditCount = await ConfigAuditCountAsync();
            Check(IsSuccess(await Controller(context).UpdateJuryHomePageTableStatus(definition.Name, false, default), false),
                "Unchanged value is an idempotent successful request.");
            Check(await RowsSnapshotAsync() == noOpSnapshot && await ConfigAuditCountAsync() == auditCount,
                "No-op does not alter IDs, values, metadata or produce a spurious database update log.");
        }
        // Keep two enabled and two disabled to exercise both preserved choices on deploy/rollback.
        foreach (var name in new[] { JuryHomePageTableSettings.JuryTable, JuryHomePageTableSettings.MostWatchedTable })
        {
            await using var context = Context();
            Check(IsSuccess(await Controller(context).UpdateJuryHomePageTableStatus(name, true, default), true),
                "A disabled table can also be enabled immediately.");
        }
        foreach (var name in new[] { "not-a-setting", "HomePageJuryTable", "homepagejurytableenabled", "HomePageJuryTableEnabled'; DROP TABLE dbo.Configs;--" })
        {
            await using var context = Context();
            var before = await MutationSnapshotAsync();
            Check(await Controller(context).UpdateJuryHomePageTableStatus(name, false, default) is NotFoundResult,
                "Unknown, incorrectly cased and injection-like names are rejected by the allowlist.");
            Check(await MutationSnapshotAsync() == before, "Rejected config name does not change settings or logs.");
        }
        await using (var context = Context())
        {
            var before = await MutationSnapshotAsync();
            Check(await Controller(context).UpdateJuryHomePageTableStatus(JuryHomePageTableSettings.JuryTable, null, default) is BadRequestObjectResult,
                "Missing isActive is rejected rather than silently interpreted as false.");
            var invalid = Controller(context);
            invalid.ModelState.AddModelError("isActive", "Malformed boolean form value.");
            Check(await invalid.UpdateJuryHomePageTableStatus(JuryHomePageTableSettings.JuryTable, true, default) is BadRequestObjectResult,
                "Malformed boolean model binding is rejected.");
            var unauthenticated = Controller(context, authenticated: false);
            Check(await unauthenticated.UpdateJuryHomePageTableStatus(JuryHomePageTableSettings.JuryTable, false, default) is ChallengeResult,
                "Missing user identity is challenged.");
            Check(await MutationSnapshotAsync() == before, "Invalid input and missing identity leave data unchanged.");
        }
        Console.WriteLine("PASS: real status endpoint, validation, no-op behavior and old/new audit values.");
    }

    private async Task TestFactoryAsync()
    {
        await using var context = Context();
        var values = await context.Configs.AsNoTracking().ToDictionaryAsync(row => row.ConfigName, row => row.ConfigValue);
        var rows = Definitions.Select(definition => new JuryHomePageTableSettingsRowViewModel
        {
            ConfigName = definition.Name, Title = definition.Title, IsAvailable = true,
            IsEnabled = JuryHomePageTableSettings.IsEnabled(values.GetValueOrDefault(definition.Name))
        }).ToArray();
        var table = JuryHomePageTableSettingsComplexTableFactory.Create(rows);
        Check(table.Tabs.Count == 1 && table.Tabs[0].Rows.Count == 4, "Table factory presents exactly the four fixed integration settings.");
        Check(table.Tabs[0].Columns.Select(column => column.Title).SequenceEqual(new[] { "Tablo Adı", "Statü" }),
            "Settings table has label and switch columns only.");
        Check(table.Tabs[0].Columns.All(column => !column.IsSortable) &&
              table.Tabs[0].Columns.Sum(column => column.ColWidth.Value) == 100,
            "Two fixed columns have valid generic widths and no unnecessary sorting.");
        Check(!table.IsEditableRows && !table.IsDeleteColActive && !table.IsNavigationColActive && !table.ShowSearch,
            "Fixed settings do not expose rename, deletion, navigation or search controls.");
        for (var index = 0; index < rows.Length; index++)
        {
            var row = table.Tabs[0].Rows[index];
            Check(row.Cells.Count == 2 && row.Cells[0].Content == rows[index].Title && row.Cells[1].ToggleChecked == rows[index].IsEnabled,
                "Factory label and switch reflect the actual stored state.");
            Check(row.Cells[1].ToggleUrl == $"/diger-ayarlar/juri-ana-ekran-tablolari/{rows[index].ConfigName}/status" && !row.Cells[1].ToggleDisabled,
                "Every switch calls the correct immediate update endpoint.");
            Check(string.IsNullOrEmpty(row.Link) && string.IsNullOrEmpty(row.EditUrl) && string.IsNullOrEmpty(row.DeleteUrl),
                "A fixed integration row cannot navigate into a generic config editing screen.");
        }
        var missing = JuryHomePageTableSettingsComplexTableFactory.Create([
            new JuryHomePageTableSettingsRowViewModel { ConfigName = Definitions[0].Name, Title = Definitions[0].Title }
        ]);
        Check(missing.Tabs[0].Rows[0].Cells[1].ToggleDisabled, "Missing deployed setting fails closed with a disabled control.");
        Check(JuryHomePageTableSettings.IsEnabled("true") && !JuryHomePageTableSettings.IsEnabled("false") &&
              !JuryHomePageTableSettings.IsEnabled(null) && !JuryHomePageTableSettings.IsEnabled("script"),
            "Stored values are interpreted as explicit boolean visibility.");
        Console.WriteLine("PASS: two-column switch factory, endpoints and preserved true/false state.");
    }

    private async Task TestDatabaseGuardsAsync()
    {
        foreach (var value in new[] { "TRUE", "True", "true ", "false ", " false", "1", "0", "", "<script>alert(1)</script>" })
            await ExpectRejectedAsync("UPDATE dbo.Configs SET ConfigValue = @value WHERE ConfigName = @name",
                "Fixed value must be an exact lowercase true/false literal.", ("@value", value), ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("UPDATE dbo.Configs SET ConfigName = N'RenamedSetting' WHERE ConfigName = @name",
            "Fixed config names cannot be renamed.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("UPDATE dbo.Configs SET ConfigName = LOWER(ConfigName) WHERE ConfigName = @name",
            "Fixed config names cannot be case-mutated.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("UPDATE dbo.Configs SET ConfigName = ConfigName + N' ' WHERE ConfigName = @name",
            "Fixed config names cannot acquire trailing whitespace.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("UPDATE dbo.Configs SET id = NEWID() WHERE ConfigName = @name",
            "Fixed config identity cannot be replaced.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("UPDATE dbo.Configs SET IsPublished = 0 WHERE ConfigName = @name",
            "Fixed configs cannot be unpublished.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("DELETE FROM dbo.Configs WHERE ConfigName = @name",
            "Existing soft-delete trigger cannot remove a fixed config.", ("@name", Definitions[0].Name));
        await ExpectRejectedAsync("""
            INSERT INTO dbo.Configs (id, ConfigName, ConfigValue, created_at, updated_at, IsPublished)
            VALUES (NEWID(), @name, N'true', SYSDATETIME(), SYSDATETIME(), 1)
            """, "Fixed key cannot acquire a duplicate row.", ("@name", Definitions[0].Name));
        var normalId = Guid.NewGuid();
        await ExecuteAsync("""
            INSERT INTO dbo.Configs (id, ConfigName, ConfigValue, created_at, updated_at, IsPublished)
            VALUES (@id, N'NonFixedRegressionSetting', N'not-boolean', SYSDATETIME(), SYSDATETIME(), 1);
            INSERT INTO dbo.Configs (id, ConfigName, ConfigValue, created_at, updated_at, IsPublished)
            VALUES (NEWID(), N'NonFixedRegressionSetting', N'another-value', SYSDATETIME(), SYSDATETIME(), 1)
            """, ("@id", normalId));
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.Configs WHERE ConfigName = N'NonFixedRegressionSetting'") == 2,
            "New uniqueness and boolean restriction do not alter ordinary config semantics.");
        await ExecuteAsync("UPDATE dbo.Configs SET ConfigName = N'RenamedRegressionSetting', ConfigValue = N'updated' WHERE id = @id", ("@id", normalId));
        await ExecuteAsync("DELETE FROM dbo.Configs WHERE id = @id", ("@id", normalId));
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.Configs WHERE id = @id AND IsPublished = 0", ("@id", normalId)) == 1,
            "Ordinary config rename and recoverable soft-delete remain supported.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.Configs WHERE ConfigName LIKE N'HomePage%TableEnabled' AND IsPublished = 1") == 4,
            "Unrelated config changes retain every fixed setting.");
        Console.WriteLine("PASS: scoped DB uniqueness, immutable names/IDs, exact values and fixed soft-delete protection.");
    }

    private async Task TestReplayAsync()
    {
        var before = await FixedRowsSnapshotAsync();
        var referencePath = Path.Combine(Directory.GetCurrentDirectory(), "src", "YKBAfife", "Migrations", "DatabaseObjects", "50-ReferenceData", "JuryHomePageTableSettings.sql");
        var referenceSql = await File.ReadAllTextAsync(referencePath, Encoding.UTF8);
        for (var replay = 0; replay < 3; replay++)
        {
            await ExecuteAsync(referenceSql);
            await using var context = Context();
            await context.Database.MigrateAsync();
            Check(await FixedRowsSnapshotAsync() == before, "Reference seed replay and no-op deployment preserve every ID, choice and timestamp.");
        }
        Console.WriteLine("PASS: repeated reference seed/deploy does not reset switch choices.");
    }

    private async Task TestRollbackAndLegacyIdAsync()
    {
        var before = await FixedRowsSnapshotAsync();
        var totalRows = await NumberAsync("SELECT COUNT(*) FROM dbo.Configs");
        await using (var context = Context()) await context.GetService<IMigrator>().MigrateAsync(previousMigration);
        Check(await FixedRowsSnapshotAsync() == before && await NumberAsync("SELECT COUNT(*) FROM dbo.Configs") == totalRows,
            "Rolling back settings migration preserves all fixed and ordinary config rows.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Configs') AND name = N'UX_Configs_JuryHomePageTableName'") == 0,
            "Rollback removes the introduced index while retaining settings data.");
        await using (var context = Context()) await context.GetService<IMigrator>().MigrateAsync(settingsMigration);
        Check(await FixedRowsSnapshotAsync() == before && await NumberAsync("SELECT COUNT(*) FROM dbo.Configs") == totalRows,
            "Reapply retains both enabled and disabled values, metadata and all existing rows.");
        await using (var context = Context()) await context.GetService<IMigrator>().MigrateAsync(previousMigration);
        var inheritedId = Guid.NewGuid();
        await ExecuteAsync("UPDATE dbo.Configs SET id = @id WHERE ConfigName = @name", ("@id", inheritedId), ("@name", Definitions[1].Name));
        var inherited = await FixedRowsSnapshotAsync();
        await using (var context = Context()) await context.Database.MigrateAsync();
        Check(await FixedRowsSnapshotAsync() == inherited && await NumberAsync("SELECT COUNT(*) FROM dbo.Configs WHERE id = @id AND ConfigValue = N'false'", ("@id", inheritedId)) == 1,
            "An existing environment's noncanonical ID and disabled value are preserved instead of replaced by seed defaults.");
        Console.WriteLine("PASS: version rollback/reapply and inherited environment IDs preserve data and choices.");
    }

    private ManagementController Controller(AfifeContext context, bool authenticated = true)
    {
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!, null!, null!,
            null!, null!, null!, null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext();
        if (authenticated && adminId != Guid.Empty)
            http.User = new ClaimsPrincipal(new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, adminId.ToString()), new Claim(ClaimTypes.Role, "Coordinator")
            ], "Regression"));
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private async Task ExpectRejectedAsync(string sql, string label, params (string Name, object Value)[] parameters)
    {
        var before = await MutationSnapshotAsync();
        var rejected = false;
        try { await ExecuteAsync(sql, parameters); }
        catch (SqlException error) when (error.Number is 2601 or 2627 or 547 or 53213) { rejected = true; }
        Check(rejected, label);
        Check(await MutationSnapshotAsync() == before, "Rejected statement rolls back config and audit mutations atomically.");
    }

    private static bool IsSuccess(IActionResult result, bool state)
    {
        if (result is not JsonResult json) return false;
        using var value = JsonDocument.Parse(JsonSerializer.Serialize(json.Value));
        return value.RootElement.GetProperty("success").GetBoolean() && value.RootElement.GetProperty("isActive").GetBoolean() == state;
    }

    private static bool HasConfigValue(string json, string name, string value)
    {
        using var document = JsonDocument.Parse(json);
        return document.RootElement.EnumerateArray().Any(row => row.TryGetProperty("ConfigName", out var key) &&
            key.GetString() == name && row.TryGetProperty("ConfigValue", out var entry) && entry.GetString() == value);
    }

    private async Task<string> MutationSnapshotAsync() => await RowsSnapshotAsync() + "|" + await ConfigAuditCountAsync();
    private Task<long> ConfigAuditCountAsync() => NumberAsync("SELECT COUNT(*) FROM dbo.AdminLogs WHERE TableName = N'Configs'");
    private Task<string> RowsSnapshotAsync() => TextAsync("SELECT * FROM dbo.Configs ORDER BY ConfigName, id FOR JSON PATH, INCLUDE_NULL_VALUES");
    private Task<string> FixedRowsSnapshotAsync() => TextAsync("SELECT * FROM dbo.Configs WHERE ConfigName LIKE N'HomePage%TableEnabled' ORDER BY ConfigName, id FOR JSON PATH, INCLUDE_NULL_VALUES");

    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var client = new SqlConnection(connection);
        await client.OpenAsync();
        await using var command = client.CreateCommand();
        command.CommandText = sql;
        command.CommandTimeout = 180;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<long> NumberAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var client = new SqlConnection(connection);
        await client.OpenAsync();
        await using var command = client.CreateCommand();
        command.CommandText = sql;
        command.CommandTimeout = 180;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        return Convert.ToInt64(await command.ExecuteScalarAsync());
    }

    private async Task<string> TextAsync(string sql)
    {
        await using var client = new SqlConnection(connection);
        await client.OpenAsync();
        await using var command = client.CreateCommand();
        command.CommandText = sql;
        command.CommandTimeout = 180;
        // FOR JSON can be emitted as multiple reader rows; preserve the complete snapshot.
        await using var reader = await command.ExecuteReaderAsync();
        var result = new StringBuilder();
        while (await reader.ReadAsync()) if (!reader.IsDBNull(0)) result.Append(reader.GetString(0));
        return result.ToString();
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + message);
        assertions++;
    }
}
