using System.Data;
using System.Globalization;
using System.Security.Claims;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Primitives;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;

var connection = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connection))
    throw new ArgumentException("Use the disposable jury birth date regression runner with --connection.");
var settings = new SqlConnectionStringBuilder(connection);
if (!Regex.IsMatch(settings.DataSource, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
    !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeJuryBirthDateTest_[a-f0-9]{32}$") || !settings.IntegratedSecurity)
    throw new ArgumentException("Only the dedicated GUID-suffixed LocalDB test database is allowed.");

await using var checks = new RegressionChecks(connection);
await checks.RunAsync();

sealed class RegressionChecks(string connection) : IAsyncDisposable
{
    private readonly Guid adminId = Guid.NewGuid();
    private readonly Guid juryId = Guid.NewGuid();
    private readonly Guid otherJuryId = Guid.NewGuid();
    private readonly Guid unpublishedJuryId = Guid.NewGuid();
    private readonly ServiceProvider services = new ServiceCollection().AddLogging().AddControllers().Services.BuildServiceProvider();
    private int assertions;

    public async Task RunAsync()
    {
        await TestDateBindingAsync();
        await CreateLegacyFixtureAsync();
        await TestAdditiveMigrationAsync();
        await TestControllerWorkflowAsync();
        Console.WriteLine($"PASS: {assertions} jury birth date assertions (SQL date migration, binding, details, edit, clear and role scope).");
    }

    private AfifeContext Context() => new(new DbContextOptionsBuilder<AfifeContext>()
        .UseSqlServer(connection)
        .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options);

    private async Task TestDateBindingAsync()
    {
        var leapDay = await BindDateAsync("2000-02-29");
        Check(leapDay.ModelState.ErrorCount == 0 && leapDay.Result.IsModelSet &&
            Equals(leapDay.Result.Model, new DateOnly(2000, 2, 29)),
            "The MVC binder accepts an ISO leap-day value from the native date input.");
        foreach (var value in new[] { "2023-02-29", "2000-13-01", "not-a-date" })
        {
            var invalid = await BindDateAsync(value);
            Check(invalid.ModelState.ErrorCount > 0, $"The MVC binder rejects '{value}'.");
        }
        var empty = await BindDateAsync(string.Empty);
        Check(empty.ModelState.ErrorCount == 0 && empty.Result.IsModelSet && empty.Result.Model is null,
            "An empty date input binds to null because the birthday is optional.");
    }

    private async Task CreateLegacyFixtureAsync()
    {
        await ExecuteAsync("""
            CREATE TABLE dbo.Users (
                Id uniqueidentifier NOT NULL PRIMARY KEY,
                FirstName nvarchar(100) NOT NULL,
                LastName nvarchar(100) NOT NULL,
                Phone nvarchar(30) NULL,
                PhotoImageId uniqueidentifier NULL,
                Username nvarchar(100) NOT NULL,
                PasswordHash nvarchar(500) NOT NULL,
                Email nvarchar(255) NOT NULL,
                CreatedAt datetime2 NULL,
                CreatedBy uniqueidentifier NULL,
                UpdatedAt datetime2 NULL,
                UpdatedBy uniqueidentifier NULL,
                IsPublished bit NOT NULL DEFAULT (1),
                IsActive bit NOT NULL DEFAULT (1),
                IsJuryPresident bit NOT NULL DEFAULT (0),
                RoleCode int NOT NULL,
                GroupCode int NULL
            );
            CREATE TABLE dbo.[Group] (
                Id uniqueidentifier NOT NULL PRIMARY KEY, Code int NOT NULL, GroupName nvarchar(255) NOT NULL,
                CreatedAt datetime2 NOT NULL, CreatedBy uniqueidentifier NULL, UpdatedAt datetime2 NULL,
                UpdatedBy uniqueidentifier NULL, IsPublished bit NOT NULL DEFAULT (1)
            );
            CREATE TABLE dbo.UsersLog (
                Id uniqueidentifier NOT NULL PRIMARY KEY, UserId uniqueidentifier NULL,
                EventType nvarchar(50) NOT NULL, IsSuccessful bit NOT NULL,
                OccurredAt datetime2 NOT NULL, IsPublished bit NOT NULL DEFAULT (1)
            );
            """);
        foreach (var row in new[]
        {
            (Id: adminId, Username: "birth.admin", Role: 1, Published: true),
            (Id: juryId, Username: "birth.jury", Role: 2, Published: true),
            (Id: otherJuryId, Username: "birth.other", Role: 2, Published: true),
            (Id: unpublishedJuryId, Username: "birth.hidden", Role: 2, Published: false)
        })
        {
            await ExecuteAsync("""
                INSERT INTO dbo.Users
                    (Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
                     CreatedAt, IsPublished, IsActive, IsJuryPresident, RoleCode)
                VALUES (@id, N'Jüri', N'Test', N'05321234567', @username, N'unchanged-existing-password', @email,
                        '2024-01-01T00:00:00', @published, 1, 0, @role);
                """, ("@id", row.Id), ("@username", row.Username), ("@email", row.Username + "@example.invalid"),
                ("@published", row.Published), ("@role", row.Role));
        }
    }

    private async Task TestAdditiveMigrationAsync()
    {
        var before = await LegacySnapshotAsync();
        await using var context = Context();
        var property = context.Model.FindEntityType(typeof(User))!.FindProperty(nameof(User.BirthDate))!;
        Check(property.ClrType == typeof(DateOnly?) && property.IsNullable && property.GetColumnType() == "date",
            "BirthDate maps to a nullable SQL date without a time or timezone component.");
        var assembly = context.GetService<IMigrationsAssembly>();
        var entry = assembly.Migrations.Single(pair => pair.Key.Contains("UserBirthDate", StringComparison.Ordinal));
        var migration = assembly.CreateMigration(entry.Value, context.Database.ProviderName!);
        var column = migration.UpOperations.OfType<AddColumnOperation>()
            .Single(operation => operation.Table == "Users" && operation.Name == nameof(User.BirthDate));
        Check(column.IsNullable && column.ColumnType == "date" && column.DefaultValue is null && column.DefaultValueSql is null,
            "The migration adds an optional birthday column with no fabricated dates for legacy users.");
        Check(!migration.UpOperations.Any(operation => operation is DropTableOperation or DropColumnOperation),
            "The birthday migration does not remove existing tables or columns.");

        // Execute the migration's actual DDL operation against the populated legacy Users table.
        // Other application SQL modules are exercised by the full migration deployment suite.
        var commands = context.GetService<IMigrationsSqlGenerator>().Generate([column], context.Model);
        foreach (var command in commands) await ExecuteAsync(command.CommandText);
        Check(await ScalarAsync<long>("SELECT COUNT(*) FROM dbo.Users WHERE BirthDate IS NULL;") == 4,
            "Every preexisting user retains a null birthday after the additive migration.");
        Check(await LegacySnapshotAsync() == before,
            "The migration leaves every preexisting user value unchanged.");
        Check(await ScalarAsync<int>("""
            SELECT COUNT(*) FROM sys.columns c
            JOIN sys.types t ON c.user_type_id = t.user_type_id
            WHERE c.object_id = OBJECT_ID(N'dbo.Users') AND c.name = N'BirthDate'
              AND t.name = N'date' AND c.is_nullable = 1;
            """) == 1, "SQL Server exposes BirthDate as one nullable date column.");
    }

    private async Task TestControllerWorkflowAsync()
    {
        var unrelatedBefore = await UnrelatedSnapshotAsync();
        await using (var context = Context())
        {
            var edit = await EditModelAsync(context, juryId);
            Check(edit.BirthDate is null, "An existing jury without a birthday opens with an empty date field.");
            Check((await DetailsModelAsync(context, juryId)).BirthDate is null,
                "Jury details accepts an existing null birthday.");
            edit.BirthDate = new DateOnly(2000, 2, 29);
            Check(await Controller(context).EditJury(juryId, edit, default) is RedirectToActionResult,
                "A valid leap-day birthday saves through the real jury edit action.");
        }
        await using (var context = Context())
        {
            var user = await context.Users.AsNoTracking().SingleAsync(user => user.Id == juryId);
            Check(user.BirthDate == new DateOnly(2000, 2, 29), "The saved birthday persists as an exact DateOnly value.");
            Check(user.PasswordHash == "unchanged-existing-password" && user.RoleCode == 2 && user.IsActive,
                "Saving a birthday preserves the jury role, password and active state.");
            Check((await EditModelAsync(context, juryId)).BirthDate == user.BirthDate &&
                (await DetailsModelAsync(context, juryId)).BirthDate == user.BirthDate,
                "Both edit and details reload the saved birthday.");
        }
        await TestExistingColumnReplayAsync();
        await using (var context = Context())
        {
            var edit = await EditModelAsync(context, juryId);
            var invalid = await BindDateAsync("2023-02-29");
            edit.BirthDate = null;
            var controller = Controller(context);
            controller.ModelState.SetModelValue(nameof(edit.BirthDate), "2023-02-29", "2023-02-29");
            foreach (var error in invalid.ModelState[nameof(edit.BirthDate)]!.Errors)
                controller.ModelState.AddModelError(nameof(edit.BirthDate), error.ErrorMessage);
            Check(await controller.EditJury(juryId, edit, default) is ViewResult &&
                controller.ModelState[nameof(edit.BirthDate)]?.Errors.Count > 0,
                "An invalid posted date survives the action's ModelState reset and returns a field error.");
            Check((await context.Users.AsNoTracking().SingleAsync(user => user.Id == juryId)).BirthDate == new DateOnly(2000, 2, 29),
                "An invalid birthday submission cannot silently clear the previously saved date.");
        }
        await using (var context = Context())
        {
            var edit = await EditModelAsync(context, juryId);
            edit.BirthDate = null;
            Check(await Controller(context).EditJury(juryId, edit, default) is RedirectToActionResult,
                "The optional birthday can be cleared through the normal edit action.");
        }
        await using (var context = Context())
        {
            Check((await EditModelAsync(context, juryId)).BirthDate is null &&
                (await DetailsModelAsync(context, juryId)).BirthDate is null,
                "Clearing persists null and both screens reload an empty birthday.");
            foreach (var excludedId in new[] { adminId, unpublishedJuryId })
            {
                var controller = Controller(context);
                Check(await controller.JuryDetails(excludedId, default) is NotFoundResult &&
                    await controller.EditJury(excludedId, default) is NotFoundResult &&
                    await controller.EditJury(excludedId, new EditJuryViewModel { Id = excludedId, BirthDate = new DateOnly(1990, 1, 1) }, default) is NotFoundResult,
                    "Birthday reads and writes remain limited to published RoleCode=2 juries.");
            }
        }
        Check(await UnrelatedSnapshotAsync() == unrelatedBefore,
            "Birthday changes leave all other users and their metadata untouched.");
    }

    private async Task TestExistingColumnReplayAsync()
    {
        var before = await ScalarAsync<string>("SELECT (SELECT * FROM dbo.Users ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);");
        await using var context = Context();
        var assembly = context.GetService<IMigrationsAssembly>();
        var entry = assembly.Migrations.Single(pair => pair.Key.Contains("UserBirthDate", StringComparison.Ordinal));
        var migration = assembly.CreateMigration(entry.Value, context.Database.ProviderName!);
        var column = migration.UpOperations.OfType<AddColumnOperation>()
            .Single(operation => operation.Table == "Users" && operation.Name == nameof(User.BirthDate));
        var commands = context.GetService<IMigrationsSqlGenerator>().Generate([column], context.Model);
        foreach (var command in commands) await ExecuteAsync(command.CommandText);
        Check((await context.Users.AsNoTracking().SingleAsync(user => user.Id == juryId)).BirthDate == new DateOnly(2000, 2, 29),
            "Adopting history and replaying the birthday column addition preserves an existing saved date.");
        Check(await ScalarAsync<string>("SELECT (SELECT * FROM dbo.Users ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);") == before,
            "Replaying the column addition leaves the existing nullable date column and every user value unchanged.");
    }

    private async Task<EditJuryViewModel> EditModelAsync(AfifeContext context, Guid id) =>
        (EditJuryViewModel)((ViewResult)await Controller(context).EditJury(id, default)).Model!;

    private async Task<JuryDetailsViewModel> DetailsModelAsync(AfifeContext context, Guid id) =>
        (JuryDetailsViewModel)((ViewResult)await Controller(context).JuryDetails(id, default)).Model!;

    private ManagementController Controller(AfifeContext context)
    {
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!, null!,
            new EmptyWatchedPlayReport(), null!, null!, null!, null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext { RequestServices = services };
        http.User = new ClaimsPrincipal(new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, adminId.ToString()), new Claim(ClaimTypes.Role, "Coordinator")
        ], "JuryBirthDateRegression"));
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        controller.TempData = new TempDataDictionary(http, new MemoryTempDataProvider());
        controller.Url = new TestUrlHelper(controller.ControllerContext);
        return controller;
    }

    private async Task<ModelBindingContext> BindDateAsync(string value)
    {
        var http = new DefaultHttpContext { RequestServices = services };
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor());
        var metadata = services.GetRequiredService<IModelMetadataProvider>().GetMetadataForType(typeof(DateOnly?));
        var binder = services.GetRequiredService<IModelBinderFactory>().CreateBinder(new ModelBinderFactoryContext
        {
            Metadata = metadata,
            BindingInfo = new BindingInfo(),
            CacheToken = typeof(DateOnly?)
        });
        var values = new FormValueProvider(BindingSource.Form,
            new FormCollection(new Dictionary<string, StringValues> { ["BirthDate"] = value }), CultureInfo.InvariantCulture);
        var binding = DefaultModelBindingContext.CreateBindingContext(action, values, metadata, new BindingInfo(), "BirthDate");
        await binder.BindModelAsync(binding);
        return binding;
    }

    private Task<string> LegacySnapshotAsync() => ScalarAsync<string>("""
        SELECT Id, FirstName, LastName, Phone, PhotoImageId, Username, PasswordHash, Email,
               CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, IsActive, IsJuryPresident, RoleCode, GroupCode
        FROM dbo.Users ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES;
        """);

    private Task<string> UnrelatedSnapshotAsync() => ScalarAsync<string>("""
        SELECT * FROM dbo.Users WHERE Id <> @id ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES;
        """, ("@id", juryId));

    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var client = new SqlConnection(connection);
        await client.OpenAsync();
        await using var command = client.CreateCommand();
        command.CommandText = sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<T> ScalarAsync<T>(string sql, params (string Name, object Value)[] parameters)
    {
        await using var client = new SqlConnection(connection);
        await client.OpenAsync();
        await using var command = client.CreateCommand();
        command.CommandText = sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value);
        return (T)Convert.ChangeType((await command.ExecuteScalarAsync())!, typeof(T), CultureInfo.InvariantCulture);
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + message);
        assertions++;
    }

    public ValueTask DisposeAsync() => services.DisposeAsync();
}

sealed class EmptyWatchedPlayReport : IJuryWatchedPlayReportService
{
    public Task<JuryWatchedPlayTableViewModel> GetPageAsync(JuryWatchedPlayTableQuery query, CancellationToken cancellationToken = default) =>
        Task.FromResult(new JuryWatchedPlayTableViewModel { JuryId = query.JuryId, JuryName = "Jüri Test" });
    public Task<JuryWatchedPlayExportViewModel> GetExportAsync(JuryWatchedPlayTableQuery query, CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();
}

sealed class MemoryTempDataProvider : ITempDataProvider
{
    public IDictionary<string, object> LoadTempData(HttpContext context) => new Dictionary<string, object>();
    public void SaveTempData(HttpContext context, IDictionary<string, object> values) { }
}

sealed class TestUrlHelper(ActionContext actionContext) : IUrlHelper
{
    public ActionContext ActionContext => actionContext;
    public string? Action(UrlActionContext actionContext) => "/jury-details";
    public string? Content(string? contentPath) => contentPath;
    public bool IsLocalUrl(string? url) => true;
    public string? Link(string? routeName, object? values) => null;
    public string? RouteUrl(UrlRouteContext routeContext) => null;
}
