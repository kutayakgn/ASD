using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Reflection;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.ModelBinding.Binders;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Primitives;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;

var connection = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (args.Length != 0 && connection is null)
    throw new ArgumentException("Use no arguments for validation checks, or --connection for the disposable LocalDB checks.");

await new RegressionChecks().RunAsync(connection);

sealed class RegressionChecks
{
    private int assertions;
    private readonly Guid adminId = Guid.NewGuid();

    public async Task RunAsync(string? connection)
    {
        await TestValidationAsync();
        TestStoredValues();
        TestEndpointMetadata();

        if (connection is not null)
        {
            ValidateTestConnection(connection);
            await TestPersistenceAsync(connection);
        }

        Console.WriteLine($"PASS: {assertions} birthday settings assertions ({(connection is null ? "validation and storage format" : "validation and disposable SQL Server persistence")}).");
    }

    private async Task TestValidationAsync()
    {
        foreach (var days in new[] { 0, 1, 10 })
            Check(Validate(Model("Doğum gününüz kutlu olsun", days)).Count == 0,
                $"{days} is a valid display duration.");

        foreach (var days in new int?[] { null, -1, 11, int.MaxValue })
            Check(Validate(Model("Doğum gününüz kutlu olsun", days)).Any(error => error.MemberNames.Contains(nameof(BirthdaySettingsViewModel.DisplayDays))),
                $"Invalid display duration {days?.ToString() ?? "missing"} is rejected.");

        foreach (var message in new[] { "", "   ", new string('a', 201) })
            Check(Validate(Model(message, 1)).Any(error => error.MemberNames.Contains(nameof(BirthdaySettingsViewModel.Message))),
                "Missing, blank, and overlong birthday messages are rejected.");

        foreach (var value in new[] { "1.5", "-0.5", "1,5", "abc", "2147483648" })
        {
            var binding = await BindDaysAsync(value);
            Check(binding.ModelState.ErrorCount > 0, $"The integer form binder rejects '{value}'.");
        }

        foreach (var value in new[] { "0", "10" })
        {
            var binding = await BindDaysAsync(value);
            Check(binding.ModelState.ErrorCount == 0 && binding.Result.IsModelSet &&
                Equals(binding.Result.Model, int.Parse(value, CultureInfo.InvariantCulture)),
                $"The integer form binder accepts '{value}'.");
        }
    }

    private void TestStoredValues()
    {
        var original = Model("Doğum gününüz kutlu olsun, \"Aslı\"! İyi ki doğdunuz. 🎂", 10);
        var json = BirthdaySettings.Serialize(original);
        using var document = JsonDocument.Parse(json);
        Check(document.RootElement.GetProperty("message").GetString() == original.Message &&
            document.RootElement.GetProperty("displayDays").GetInt32() == original.DisplayDays,
            "A single BirthdaySettings JSON value contains the message and integer day count.");
        var loaded = BirthdaySettings.Parse(json);
        Check(loaded.Message == original.Message && loaded.DisplayDays == 10,
            "Turkish text, quotes and emoji survive a save/load round trip.");

        var defaults = BirthdaySettings.Parse(null);
        Check(!string.IsNullOrWhiteSpace(defaults.Message) && defaults.DisplayDays is >= 0 and <= 10,
            "An absent saved setting supplies usable initial form values.");
        var malformed = BirthdaySettings.Parse("not-json");
        Check(malformed.Message == defaults.Message && malformed.DisplayDays == defaults.DisplayDays,
            "Malformed stored JSON safely falls back to initial form values.");
    }

    private void TestEndpointMetadata()
    {
        var endpoint = typeof(ManagementController).GetMethod(nameof(ManagementController.SaveBirthdaySettings))!;
        Check(endpoint.GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>().Any(attribute => attribute.Roles == "Coordinator"),
            "Only coordinators can save birthday settings.");
        Check(endpoint.IsDefined(typeof(ValidateAntiForgeryTokenAttribute), true),
            "Saving requires an antiforgery token.");
        Check(endpoint.IsDefined(typeof(AdminMutationAuditAttribute), true),
            "Birthday settings saves participate in the existing admin mutation audit.");
    }

    private async Task TestPersistenceAsync(string connection)
    {
        await using (var sql = new SqlConnection(connection))
        {
            await sql.OpenAsync();
            await using var command = sql.CreateCommand();
            command.CommandText = """
                CREATE TABLE dbo.Configs (
                    id uniqueidentifier NOT NULL PRIMARY KEY,
                    ConfigName nvarchar(255) NOT NULL,
                    ConfigValue nvarchar(255) NOT NULL,
                    created_at datetime2 NOT NULL,
                    created_by uniqueidentifier NULL,
                    updated_at datetime2 NOT NULL,
                    updated_by uniqueidentifier NULL,
                    IsPublished bit NOT NULL DEFAULT (1)
                );
                """;
            await command.ExecuteNonQueryAsync();
        }

        await using (var context = Context(connection))
        {
            context.Configs.Add(new Config
            {
                Id = Guid.NewGuid(), ConfigName = "ExistingOtherSetting", ConfigValue = "preserved",
                CreatedAt = new DateTime(2024, 1, 1), UpdatedAt = new DateTime(2024, 1, 1), IsPublished = true
            });
            await context.SaveChangesAsync();
        }

        await using (var context = Context(connection))
        {
            var rowsBeforeLoad = await context.Configs.IgnoreQueryFilters().CountAsync();
            var initial = await LoadSettingsAsync(Controller(context));
            Check(!string.IsNullOrWhiteSpace(initial.Message) && initial.DisplayDays == 0,
                "Loading an absent setting supplies populated initial form values.");
            Check(await context.Configs.IgnoreQueryFilters().CountAsync() == rowsBeforeLoad,
                "Loading initial form values does not create or modify a config row.");
            var unauthenticated = Controller(context, authenticated: false);
            Check(await unauthenticated.SaveBirthdaySettings(Model("Doğum gününüz kutlu olsun", 2), default) is ChallengeResult,
                "A request lacking a user identity cannot create a setting.");
            Check(!await context.Configs.AnyAsync(config => config.ConfigName == BirthdaySettings.ConfigName),
                "Rejected unauthenticated saves do not create a BirthdaySettings row.");
        }

        var concurrentSaves = await Task.WhenAll(Enumerable.Range(0, 2).Select(async index =>
        {
            await using var context = Context(connection);
            return await Controller(context).SaveBirthdaySettings(Model($"Mutlu yıllar {index}!", index), default);
        }));
        Check(concurrentSaves.Any(IsSuccess) && concurrentSaves.All(result => IsSuccess(result) || result is ConflictObjectResult),
            "Simultaneous first saves either succeed or report a controlled conflict.");
        await using (var context = Context(connection))
        {
            Check(await context.Configs.IgnoreQueryFilters().CountAsync(config => config.ConfigName == BirthdaySettings.ConfigName) == 1,
                "Simultaneous first saves create at most one birthday settings row.");
            await context.Configs.IgnoreQueryFilters()
                .Where(config => config.ConfigName == BirthdaySettings.ConfigName).ExecuteDeleteAsync();
        }

        var firstMessage = "Doğum gününüz kutlu olsun, \"Aslı\"!";
        Guid savedId;
        DateTime createdAt;
        await using (var context = Context(connection))
        {
            Check(IsSuccess(await Controller(context).SaveBirthdaySettings(Model(firstMessage, 0), default)),
                "The first valid save creates BirthdaySettings with zero days.");
            var saved = await context.Configs.AsNoTracking().SingleAsync(config => config.ConfigName == BirthdaySettings.ConfigName);
            savedId = saved.Id;
            createdAt = saved.CreatedAt;
            Check(saved.CreatedBy == adminId && saved.UpdatedBy == adminId && saved.IsPublished,
                "A new config records the current administrator and is published.");
            var values = BirthdaySettings.Parse(saved.ConfigValue);
            Check(values.Message == firstMessage && values.DisplayDays == 0,
                "The persisted values populate the message and zero-day fields correctly.");
            var formValues = await LoadSettingsAsync(Controller(context));
            Check(formValues.Message == firstMessage && formValues.DisplayDays == 0,
                "The settings page loader returns the saved message and zero-day value.");
        }

        await using (var context = Context(connection))
        {
            Check(IsSuccess(await Controller(context).SaveBirthdaySettings(Model("Nice mutlu yıllara, jüri üyemiz!", 10), default)),
                "An existing birthday setting can be updated to ten days.");
            var saved = await context.Configs.AsNoTracking().SingleAsync(config => config.ConfigName == BirthdaySettings.ConfigName);
            Check(saved.Id == savedId && saved.CreatedAt == createdAt && saved.CreatedBy == adminId,
                "An update preserves the existing row identity and creation metadata.");
            Check(BirthdaySettings.Parse(saved.ConfigValue).DisplayDays == 10,
                "The updated display duration reloads as ten days.");
            var formValues = await LoadSettingsAsync(Controller(context));
            Check(formValues.Message == "Nice mutlu yıllara, jüri üyemiz!" && formValues.DisplayDays == 10,
                "Reopening the settings form returns the updated message and ten-day value.");
            Check(await context.Configs.CountAsync(config => config.ConfigName == BirthdaySettings.ConfigName) == 1,
                "Repeated saves do not create duplicate birthday settings.");
        }

        await using (var context = Context(connection))
        {
            var before = (await context.Configs.AsNoTracking().SingleAsync(config => config.Id == savedId)).ConfigValue;
            foreach (var invalid in new[] { Model("Hello", -1), Model("Hello", 11), Model("Hello", null), Model(" ", 2) })
            {
                var controller = Controller(context);
                AddValidationErrors(controller, invalid);
                Check(await controller.SaveBirthdaySettings(invalid, default) is BadRequestObjectResult,
                    "Invalid form submissions are rejected by the save endpoint.");
            }

            // Quotes expand in JSON even though the visible message fits its character limit.
            var expanded = Model(new string('"', 200), 2);
            if (BirthdaySettings.Serialize(expanded).Length > 255)
            {
                Check(await Controller(context).SaveBirthdaySettings(expanded, default) is BadRequestObjectResult,
                    "A JSON value exceeding the existing ConfigValue column is rejected before persistence.");
            }
            var after = await context.Configs.AsNoTracking().SingleAsync(config => config.Id == savedId);
            Check(after.ConfigValue == before,
                "Rejected input leaves the saved birthday message and duration unchanged.");
        }

        await using (var context = Context(connection))
        {
            var saved = await context.Configs.SingleAsync(config => config.Id == savedId);
            saved.IsPublished = false;
            await context.SaveChangesAsync();
        }
        await using (var context = Context(connection))
        {
            Check(IsSuccess(await Controller(context).SaveBirthdaySettings(Model("İyi ki doğdunuz!", 3), default)),
                "Saving revives an unpublished birthday setting instead of adding a second row.");
            var rows = await context.Configs.IgnoreQueryFilters()
                .Where(config => config.ConfigName == BirthdaySettings.ConfigName).ToListAsync();
            Check(rows.Count == 1 && rows[0].Id == savedId && rows[0].IsPublished,
                "The revived setting retains its original row ID.");
            var other = await context.Configs.SingleAsync(config => config.ConfigName == "ExistingOtherSetting");
            Check(other.ConfigValue == "preserved" && other.UpdatedAt == new DateTime(2024, 1, 1),
                "Birthday settings changes leave unrelated config values and audit metadata untouched.");
        }
    }

    private static void ValidateTestConnection(string connection)
    {
        var settings = new SqlConnectionStringBuilder(connection);
        var allowedServer = Environment.GetEnvironmentVariable("AFIFE_TEST_SQL_SERVER") ?? @"(localdb)\MSSQLLocalDB";
        if (!Regex.IsMatch(allowedServer, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
            !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeBirthdaySettingsTest_[a-f0-9]{32}$") ||
            !string.Equals(settings.DataSource, allowedServer, StringComparison.OrdinalIgnoreCase) || !settings.IntegratedSecurity)
            throw new ArgumentException("Only the runner's GUID-suffixed disposable LocalDB test database is allowed.");
    }

    private static AfifeContext Context(string connection) => new(new DbContextOptionsBuilder<AfifeContext>()
        .UseSqlServer(connection).Options);

    private ManagementController Controller(AfifeContext context, bool authenticated = true)
    {
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!, null!, null!,
            null!, null!, null!, null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext();
        if (authenticated)
            http.User = new ClaimsPrincipal(new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, adminId.ToString()), new Claim(ClaimTypes.Role, "Coordinator")
            ], "BirthdaySettingsRegression"));
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private static BirthdaySettingsViewModel Model(string message, int? days) => new() { Message = message, DisplayDays = days };

    private static List<ValidationResult> Validate(BirthdaySettingsViewModel model)
    {
        var errors = new List<ValidationResult>();
        Validator.TryValidateObject(model, new ValidationContext(model), errors, validateAllProperties: true);
        return errors;
    }

    private static void AddValidationErrors(Controller controller, BirthdaySettingsViewModel model)
    {
        foreach (var error in Validate(model))
            foreach (var name in error.MemberNames)
                controller.ModelState.AddModelError(name, error.ErrorMessage ?? "Invalid field.");
    }

    private static Task<BirthdaySettingsViewModel> LoadSettingsAsync(ManagementController controller) =>
        (Task<BirthdaySettingsViewModel>)typeof(ManagementController)
            .GetMethod("LoadBirthdaySettingsAsync", BindingFlags.Instance | BindingFlags.NonPublic)!
            .Invoke(controller, [CancellationToken.None])!;

    private static async Task<ModelBindingContext> BindDaysAsync(string value)
    {
        var action = new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor());
        var provider = new FormValueProvider(BindingSource.Form,
            new FormCollection(new Dictionary<string, StringValues> { ["DisplayDays"] = value }), CultureInfo.InvariantCulture);
        var binding = DefaultModelBindingContext.CreateBindingContext(action, provider,
            new EmptyModelMetadataProvider().GetMetadataForType(typeof(int?)), new BindingInfo(), "DisplayDays");
        await new SimpleTypeModelBinder(typeof(int?), NullLoggerFactory.Instance).BindModelAsync(binding);
        return binding;
    }

    private static bool IsSuccess(IActionResult result)
    {
        if (result is not JsonResult json) return false;
        using var document = JsonDocument.Parse(JsonSerializer.Serialize(json.Value));
        return document.RootElement.GetProperty("success").GetBoolean();
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + message);
        assertions++;
    }
}
