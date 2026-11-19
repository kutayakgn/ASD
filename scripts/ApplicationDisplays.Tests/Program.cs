using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;

var connection = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (args.Length != 0 && string.IsNullOrWhiteSpace(connection))
    throw new ArgumentException("Use no arguments for codec checks, or --connection for disposable LocalDB controller checks.");
if (connection is not null)
{
    var settings = new SqlConnectionStringBuilder(connection);
    if (!Regex.IsMatch(settings.DataSource, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
        !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeApplicationDisplaysTest_[a-f0-9]{32}$") || !settings.IntegratedSecurity)
        throw new ArgumentException("Only the dedicated GUID-suffixed LocalDB fixture is allowed.");
}
await new RegressionChecks().RunAsync(connection);

sealed class RegressionChecks
{
    private const string Original = """
        [
          { "Location": "Backfill Sahne", "Date": "08/11/2025", "Time": "20:00", "external": { "id": 7 }, "flag": true },
          { "Location": "Kadıköy Sahnesi", "Date": "09/11/2025", "Time": "23:59", "ticketUrl": "https://example.invalid/ticket" }
        ]
        """;
    private const string Legacy = """
        [ { "Stage": "Eski Sahne", "Date": "2023-10-20", "legacyId": 42 } ]
        """;
    private const string ActualSubmission = """
        [
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"30/09/2025","Time":"20:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"12/10/2025","Time":"20:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"13/10/2025","Time":"20:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"14/10/2025","Time":"20:30"},
          {"Location":"ANKARA CONGRESIUM ","Date":"17/10/2025","Time":"20:30"},
          {"Location":"ANKARA CONGRESIUM ","Date":"24/10/2025","Time":"20:30"},
          {"Location":"ANKARA CONGRESIUM ","Date":"25/10/2025","Time":"20:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"26/10/2025","Time":"19:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"10/11/2025","Time":"20:30"},
          {"Location":"ZORLUPSMTURKCELL SAHNESİ","Date":"19/11/2025","Time":"20:30"}
        ]
        """;
    private const string Unsorted = """
        [
          {"Location":"Son tarih","Date":"20/11/2026","Time":"20:00","externalId":"latest"},
          {"Location":"Aynı gün geç saat","Date":"19/11/2026","Time":"21:30","externalId":"same-day-late"},
          {"Location":"İlk tarih","Date":"18/11/2026","Time":"23:00","externalId":"earliest"},
          {"Location":"Aynı gün erken saat","Date":"19/11/2026","Time":"09:15","externalId":"same-day-early"}
        ]
        """;
    private int assertions;

    public async Task RunAsync(string? connection)
    {
        TestCanonicalAndLegacyRecords();
        TestActualSubmission();
        TestChronologicalDisplayOrder();
        TestEditingAndMetadata();
        TestInvalidInput();
        if (connection is not null) await TestControllerAsync(connection);
        Console.WriteLine($"PASS: {assertions} application display assertions ({(connection is null ? "codec" : "codec and disposable SQL Server controller round trips")}).");
    }

    private void TestChronologicalDisplayOrder()
    {
        ApplicationDisplays.TryParse(Unsorted, out var sourceRows);
        var sorted = ApplicationDisplays.InDisplayOrder(sourceRows);
        Check(sorted.Select(row => row.OriginalIndex).SequenceEqual(new int?[] { 2, 3, 1, 0 }),
            "Initial display ordering uses oldest date and then earliest time while retaining source indices.");
        Check(sourceRows.Select(row => row.OriginalIndex).SequenceEqual(new int?[] { 0, 1, 2, 3 }),
            "Ordering for display leaves the parsed source collection order unchanged.");
        Check(ApplicationDisplays.TrySerialize(Unsorted, sorted, out var unchanged, out _) && unchanged == Unsorted,
            "Unchanged rows posted in chronological display order preserve the exact unsorted source JSON.");
        sorted[1].Location = "Yalnızca seçilen gösterim değişti";
        Check(ApplicationDisplays.TrySerialize(Unsorted, sorted, out var edited, out _),
            "A row reached through chronological order can still be edited.");
        using var json = JsonDocument.Parse(edited);
        var editedTarget = json.RootElement.EnumerateArray().Single(row => row.GetProperty("externalId").GetString() == "same-day-early");
        Check(editedTarget.GetProperty("Location").GetString() == sorted[1].Location &&
            editedTarget.GetProperty("Time").GetString() == "09:15" &&
            json.RootElement.EnumerateArray().Single(row => row.GetProperty("externalId").GetString() == "latest")
                .GetProperty("Location").GetString() == "Son tarih",
            "OriginalIndex keeps unknown metadata attached to the correct row after display sorting.");
    }

    private void TestActualSubmission()
    {
        Check(ApplicationDisplays.TryParse(ActualSubmission, out var rows) && rows.Count == 10,
            "The user's ten-row Display payload loads every submitted performance.");
        Check(rows[0].Date == new DateOnly(2025, 9, 30) && rows[9].Date == new DateOnly(2025, 11, 19) &&
            rows.Select(row => row.OriginalIndex).SequenceEqual(Enumerable.Range(0, 10).Select(index => (int?)index)),
            "The actual submission retains its original performance order and date range.");
        Check(rows[7].Date == new DateOnly(2025, 10, 26) && rows[7].Time == new TimeOnly(19, 30) &&
            rows.Where((_, index) => index != 7).All(row => row.Time == new TimeOnly(20, 30)),
            "The actual submission retains the exceptional 19:30 time and all 20:30 performances.");
        Check(rows[4].Location == "ANKARA CONGRESIUM " && rows[5].Location == "ANKARA CONGRESIUM " && rows[6].Location == "ANKARA CONGRESIUM ",
            "Existing trailing whitespace in the Ankara venue is retained.");
        Check(ApplicationDisplays.TrySerialize(ActualSubmission, rows, out var json, out _) && json == ActualSubmission,
            "An unchanged ten-row submission round-trips byte-for-byte.");
        rows[0].Time = new TimeOnly(21, 45);
        Check(ApplicationDisplays.TrySerialize(ActualSubmission, rows, out json, out _) &&
            ApplicationDisplays.TryParse(json, out var reloaded) && reloaded[4].Location == "ANKARA CONGRESIUM " &&
            reloaded[0].Time == new TimeOnly(21, 45) && reloaded[7].Time == new TimeOnly(19, 30),
            "Editing one performance time leaves the other venues and performance times unchanged.");
    }

    private void TestCanonicalAndLegacyRecords()
    {
        Check(ApplicationDisplays.TryParse(Original, out var rows) && rows.Count == 2,
            "Multiple display rows can be read from the existing Form.Display JSON array.");
        Check(rows[0].OriginalIndex == 0 && rows[0].Location == "Backfill Sahne" &&
            rows[0].Date == new DateOnly(2025, 11, 8) && rows[0].Time == new TimeOnly(20, 0),
            "Location, dd/MM/yyyy date and HH:mm time are parsed without timezone conversion.");
        Check(rows[1].OriginalIndex == 1 && rows[1].Date == new DateOnly(2025, 11, 9) && rows[1].Time == new TimeOnly(23, 59),
            "Row ordering and the latest valid minute of the day are preserved.");
        Check(ApplicationDisplays.TrySerialize(Original, rows, out var unchanged, out _) && unchanged == Original,
            "Submitting semantically unchanged rows preserves the exact original JSON including whitespace and unknown properties.");
        Check(ApplicationDisplays.TryParse(Legacy, out var legacy) && legacy.Count == 1 &&
            legacy[0].Location == "Eski Sahne" && legacy[0].Date == new DateOnly(2023, 10, 20) && legacy[0].Time is null,
            "Legacy Stage/ISO-date records remain readable without inventing a time.");
        Check(ApplicationDisplays.TrySerialize(Legacy, legacy, out var sameLegacy, out _) && sameLegacy == Legacy,
            "An untouched legacy record retains its exact original representation.");
        foreach (var empty in new string?[] { null, string.Empty, "  ", "[]" })
            Check(ApplicationDisplays.TryParse(empty, out var noRows) && noRows.Count == 0,
                "Missing display data and an empty array load as an empty editable collection.");
    }

    private void TestEditingAndMetadata()
    {
        ApplicationDisplays.TryParse(Original, out var rows);
        rows[0].Location = "Üsküdar \"Özel\" Sahnesi\\Fuaye";
        rows[0].Date = new DateOnly(2000, 2, 29);
        rows[0].Time = new TimeOnly(0, 0);
        Check(ApplicationDisplays.TrySerialize(Original, rows, out var changed, out _),
            "Existing rows can update location, leap-day date and midnight time.");
        using (var document = JsonDocument.Parse(changed))
        {
            var first = document.RootElement[0];
            Check(first.GetProperty("external").GetProperty("id").GetInt32() == 7 && first.GetProperty("flag").GetBoolean(),
                "Editing a display row preserves unknown nested JSON and scalar properties.");
            Check(first.GetProperty("Location").GetString() == rows[0].Location &&
                first.GetProperty("Date").GetString() == "29/02/2000" && first.GetProperty("Time").GetString() == "00:00",
                "Existing canonical property names and date/time format are retained when editing.");
            Check(document.RootElement[1].GetProperty("ticketUrl").GetString() == "https://example.invalid/ticket",
                "Editing the first row retains unknown data belonging to the second row.");
        }
        Check(ApplicationDisplays.TryParse(changed, out var readBack) && readBack[0].Location == rows[0].Location &&
            readBack[0].Date == rows[0].Date && readBack[0].Time == rows[0].Time,
            "Turkish text, quotes, backslashes, date and time survive a complete round trip.");

        ApplicationDisplays.TryParse(Legacy, out var legacy);
        legacy[0].Location = "Yenilenen Eski Sahne";
        legacy[0].Date = new DateOnly(2024, 2, 29);
        Check(ApplicationDisplays.TrySerialize(Legacy, legacy, out var changedLegacy, out _),
            "Legacy Stage rows can be edited.");
        using (var document = JsonDocument.Parse(changedLegacy))
        {
            var first = document.RootElement[0];
            Check(first.GetProperty("Stage").GetString() == legacy[0].Location &&
                first.GetProperty("Date").GetString() == "2024-02-29" && first.GetProperty("legacyId").GetInt32() == 42,
                "Editing legacy data retains its Stage key, ISO-date format and unknown ID.");
            Check(!first.TryGetProperty("Time", out var time) || time.ValueKind is JsonValueKind.Null || time.GetString() == string.Empty,
                "Editing another field does not fabricate a missing legacy time.");
        }

        ApplicationDisplays.TryParse(Original, out var survivingRows);
        Check(ApplicationDisplays.TrySerialize(Original, [survivingRows[1]], out var deleted, out _),
            "An explicitly removed display row can be deleted.");
        using (var document = JsonDocument.Parse(deleted))
            Check(document.RootElement.GetArrayLength() == 1 &&
                document.RootElement[0].GetProperty("ticketUrl").GetString() == "https://example.invalid/ticket",
                "Removing the first row preserves the second row's metadata through its original index.");

        Check(ApplicationDisplays.TrySerialize(null, [NewRow("Yeni \"İstanbul\" Sahnesi", new DateOnly(2026, 11, 19), new TimeOnly(21, 7))],
            out var added, out _) && ApplicationDisplays.TryParse(added, out var newRows) &&
            newRows.Count == 1 && newRows[0].Date == new DateOnly(2026, 11, 19) && newRows[0].Time == new TimeOnly(21, 7),
            "New rows are serializable and retain independent date and minute-precision time values.");
    }

    private void TestInvalidInput()
    {
        foreach (var raw in new[] { "not-json", "{}", "null", "[null]", "[\"row\"]",
                     "[{\"Location\":\"X\",\"Date\":\"29/02/2025\"}]",
                     "[{\"Location\":\"X\",\"Date\":\"19/11/2026\",\"Time\":\"24:00\"}]" })
        {
            Check(!ApplicationDisplays.TryParse(raw, out _), "Malformed or unsupported display data is detected.");
            Check(!ApplicationDisplays.TrySerialize(raw, [NewRow("Replacement", new DateOnly(2026, 11, 19), null)], out _, out var error) &&
                !string.IsNullOrWhiteSpace(error), "Unrecognized existing JSON cannot be implicitly replaced.");
        }
        foreach (var row in new[] { NewRow(" ", new DateOnly(2026, 11, 19), null), NewRow("Sahne", null, null) })
            Check(!ApplicationDisplays.TrySerialize("[]", [row], out _, out var error) && !string.IsNullOrWhiteSpace(error),
                "A display row requires both a location and a valid date.");
        foreach (var index in new[] { -1, 2, int.MaxValue })
            Check(!ApplicationDisplays.TrySerialize(Original, [NewRow("Sahne", new DateOnly(2026, 11, 19), null, index)], out _, out _),
                "An invalid original index cannot target another JSON record.");
        Check(!ApplicationDisplays.TrySerialize(Original,
            [NewRow("Bir", new DateOnly(2026, 11, 19), null, 0), NewRow("İki", new DateOnly(2026, 11, 20), null, 0)], out _, out _),
            "The same original row cannot be submitted twice.");
    }

    private async Task TestControllerAsync(string connection)
    {
        await using (var context = Context(connection))
        {
            // This fixture contains the existing Form shape only; no application migrations or triggers are run.
            await context.Database.ExecuteSqlRawAsync("""
                CREATE TABLE dbo.Form (
                    Id uniqueidentifier NOT NULL PRIMARY KEY DEFAULT (newsequentialid()), LegacyId int NULL,
                    ApplicationNumber nvarchar(6) NOT NULL, SeasonId uniqueidentifier NULL,
                    CreatedDate datetime NULL, UpdatedDate datetime NULL, RepertoireName nvarchar(500) NOT NULL,
                    TheatreName nvarchar(500) NOT NULL, PremiereDate date NOT NULL, Display nvarchar(max) NOT NULL,
                    ApplicantName nvarchar(100) NOT NULL, ApplicantRole nvarchar(200) NOT NULL,
                    Phone nvarchar(20) NOT NULL, Email nvarchar(150) NOT NULL, Director nvarchar(100) NULL,
                    ContactName nvarchar(100) NULL, ContactPhone nvarchar(20) NULL, LeadActress nvarchar(max) NULL,
                    LeadActor nvarchar(max) NULL, SupportActress nvarchar(max) NULL, SupportActor nvarchar(max) NULL,
                    StageDesign nvarchar(1000) NULL, ClothesDesign nvarchar(1000) NULL, LightDesign nvarchar(1000) NULL,
                    StageMusic nvarchar(1000) NULL, Choreography nvarchar(1000) NULL, YoungGenerationArtist nvarchar(max) NULL,
                    previousProductionVersion bit NOT NULL DEFAULT (0), IsActive bit NOT NULL DEFAULT (1), IsPublished bit NOT NULL DEFAULT (1)
                );
                """);
            context.Forms.AddRange(Form("000001", Original), Form("000002", "opaque legacy display data"),
                Form("000003", Original), Form("000004", ActualSubmission), Form("000005", Unsorted));
            await context.SaveChangesAsync();
        }
        Guid formId;
        Guid opaqueId;
        Guid unchangedId;
        await using (var context = Context(connection))
        {
            formId = await context.Forms.Where(form => form.ApplicationNumber == "000001").Select(form => form.Id).SingleAsync();
            opaqueId = await context.Forms.Where(form => form.ApplicationNumber == "000002").Select(form => form.Id).SingleAsync();
            unchangedId = await context.Forms.Where(form => form.ApplicationNumber == "000003").Select(form => form.Id).SingleAsync();
            var edit = await EditModelAsync(context, formId);
            Check(edit.DisplaysAvailable && edit.Displays.Count == 2,
                "The real edit GET loads existing display rows.");
            var details = (ApplicationDetailsViewModel)((ViewResult)await Controller(context).ApplicationDetails(formId, default)).Model!;
            Check(details.DisplaysAvailable && details.Displays[0].Time == new TimeOnly(20, 0),
                "The real details GET loads the display date and time.");
            edit.Displays[0].Location = "Sadece gösterim alanı değişti";
            edit.DisplaysEdited = true;
            Check(await Controller(context).EditApplication(formId, edit, default) is RedirectToActionResult,
                "An edit changing only display rows saves instead of being ignored as no changes.");
        }
        await using (var context = Context(connection))
        {
            var saved = await context.Forms.AsNoTracking().SingleAsync(form => form.Id == formId);
            Check(ApplicationDisplays.TryParse(saved.Display, out var rows) && rows[0].Location == "Sadece gösterim alanı değişti",
                "The edited display row actually persists to Form.Display.");
            using var json = JsonDocument.Parse(saved.Display);
            Check(json.RootElement[0].GetProperty("external").GetProperty("id").GetInt32() == 7,
                "The controller round trip preserves unknown JSON properties.");
            var before = saved.Display;
            var edit = await EditModelAsync(context, formId);
            edit.DisplaysEdited = true;
            edit.Displays[0].Date = null;
            var controller = Controller(context);
            AddValidationErrors(controller, edit);
            Check(await controller.EditApplication(formId, edit, default) is ViewResult && !controller.ModelState.IsValid,
                "Invalid display rows return validation instead of saving.");
            Check((await context.Forms.AsNoTracking().SingleAsync(form => form.Id == formId)).Display == before,
                "Invalid display rows leave the saved raw JSON unchanged.");
        }
        await using (var context = Context(connection))
        {
            var edit = await EditModelAsync(context, opaqueId);
            Check(!edit.DisplaysAvailable, "The edit form detects unsupported existing display data.");
            edit.PlayName = "Başka alan güncellendi";
            edit.DisplaysEdited = false;
            Check(await Controller(context).EditApplication(opaqueId, edit, default) is RedirectToActionResult,
                "Other application fields remain editable when display JSON is unsupported.");
        }
        await using (var context = Context(connection))
        {
            var saved = await context.Forms.AsNoTracking().SingleAsync(form => form.Id == opaqueId);
            Check(saved.Display == "opaque legacy display data" && saved.RepertoireName == "Başka alan güncellendi",
                "Saving other fields preserves the exact unsupported display string.");
            var edit = await EditModelAsync(context, opaqueId);
            edit.PlayName = "This must not save";
            edit.DisplaysEdited = true;
            edit.Displays = [NewRow("Replacement", new DateOnly(2026, 11, 19), null)];
            var controller = Controller(context);
            Check(await controller.EditApplication(opaqueId, edit, default) is ViewResult,
                "A forged edited flag cannot overwrite unsupported original JSON.");
            Check((await context.Forms.AsNoTracking().SingleAsync(form => form.Id == opaqueId)).RepertoireName == "Başka alan güncellendi",
                "A rejected display replacement does not partially save other fields.");
        }
        await using (var context = Context(connection))
        {
            var edit = await EditModelAsync(context, unchangedId);
            edit.ContactName = "Yeni iletişim kişisi";
            edit.DisplaysEdited = false;
            Check(await Controller(context).EditApplication(unchangedId, edit, default) is RedirectToActionResult,
                "An unrelated field update saves alongside recognized display rows.");
            Check((await context.Forms.AsNoTracking().SingleAsync(form => form.Id == unchangedId)).Display == Original,
                "DisplaysEdited=false preserves exact recognized JSON formatting and unknown data.");
        }
        await using (var context = Context(connection))
        {
            var actualId = await context.Forms.Where(form => form.ApplicationNumber == "000004").Select(form => form.Id).SingleAsync();
            var edit = await EditModelAsync(context, actualId);
            edit.DisplaysEdited = true;
            edit.Displays[0].Time = new TimeOnly(21, 45);
            Check(await Controller(context).EditApplication(actualId, edit, default) is RedirectToActionResult,
                "The actual ten-row submission supports changing only one performance time.");
            var saved = await context.Forms.AsNoTracking().SingleAsync(form => form.Id == actualId);
            Check(ApplicationDisplays.TryParse(saved.Display, out var rows) && rows.Count == 10 &&
                rows[0].Time == new TimeOnly(21, 45) && rows[4].Location == "ANKARA CONGRESIUM ",
                "The controller preserves untouched venue whitespace when saving another row's time.");
        }
        await using (var context = Context(connection))
        {
            var unsortedId = await context.Forms.Where(form => form.ApplicationNumber == "000005").Select(form => form.Id).SingleAsync();
            var edit = await EditModelAsync(context, unsortedId);
            var details = (ApplicationDetailsViewModel)((ViewResult)await Controller(context).ApplicationDetails(unsortedId, default)).Model!;
            Check(edit.Displays.Select(row => row.OriginalIndex).SequenceEqual(new int?[] { 2, 3, 1, 0 }) &&
                details.Displays.Select(row => row.OriginalIndex).SequenceEqual(new int?[] { 2, 3, 1, 0 }),
                "Both real GET actions show unsorted stored performances in chronological date/time order.");
            Check((await context.Forms.AsNoTracking().SingleAsync(form => form.Id == unsortedId)).Display == Unsorted,
                "Reading either screen does not rewrite the stored source JSON.");
            edit.Displays = edit.Displays.OrderBy(row => row.OriginalIndex).ToList();
            var invalidOtherField = Controller(context);
            invalidOtherField.ModelState.AddModelError(nameof(edit.PlayName), "An unrelated field is invalid.");
            var redisplayed = (ViewResult)await invalidOtherField.EditApplication(unsortedId, edit, default);
            Check(((EditApplicationViewModel)redisplayed.Model!).Displays.Select(row => row.OriginalIndex)
                .SequenceEqual(new int?[] { 2, 3, 1, 0 }),
                "An unedited display collection stays chronologically sorted when another field returns POST validation errors.");
            edit.DisplaysEdited = true;
            edit.ContactName = "Gösterim dışı değişiklik";
            Check(await Controller(context).EditApplication(unsortedId, edit, default) is RedirectToActionResult &&
                (await context.Forms.AsNoTracking().SingleAsync(form => form.Id == unsortedId)).Display == Unsorted,
                "Saving unchanged chronologically displayed rows alongside another field preserves exact source JSON.");
        }
        await using (var context = Context(connection))
        {
            var unsortedId = await context.Forms.Where(form => form.ApplicationNumber == "000005").Select(form => form.Id).SingleAsync();
            var edit = await EditModelAsync(context, unsortedId);
            edit.Displays.Single(row => row.OriginalIndex == 3).Location = "Kronolojik hedef güncellendi";
            edit.DisplaysEdited = true;
            Check(await Controller(context).EditApplication(unsortedId, edit, default) is RedirectToActionResult,
                "Editing a chronologically displayed target saves through the controller.");
            using var json = JsonDocument.Parse((await context.Forms.AsNoTracking().SingleAsync(form => form.Id == unsortedId)).Display);
            Check(json.RootElement.EnumerateArray().Single(row => row.GetProperty("externalId").GetString() == "same-day-early")
                .GetProperty("Location").GetString() == "Kronolojik hedef güncellendi" &&
                json.RootElement.EnumerateArray().Single(row => row.GetProperty("externalId").GetString() == "earliest")
                .GetProperty("Location").GetString() == "İlk tarih",
                "A controller edit after sorting preserves target identity and unrelated row metadata.");
        }
    }

    private static AfifeContext Context(string connection) => new(new DbContextOptionsBuilder<AfifeContext>().UseSqlServer(connection).Options);
    private static Form Form(string number, string raw) => new()
    {
        Id = Guid.NewGuid(), ApplicationNumber = number, RepertoireName = "Test oyunu", TheatreName = "Test tiyatrosu",
        PremiereDate = new DateOnly(2025, 11, 1), Display = raw, ApplicantName = "Test Başvuran", ApplicantRole = "Yönetmen",
        Phone = "05321234567", Email = number + "@example.invalid", IsActive = true, IsPublished = true
    };
    private static ApplicationDisplayViewModel NewRow(string location, DateOnly? date, TimeOnly? time, int? originalIndex = null) =>
        new() { OriginalIndex = originalIndex, Location = location, Date = date, Time = time };
    private static async Task<EditApplicationViewModel> EditModelAsync(AfifeContext context, Guid id) =>
        (EditApplicationViewModel)((ViewResult)await Controller(context).EditApplication(id, default)).Model!;
    private static ManagementController Controller(AfifeContext context)
    {
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!, null!, null!,
            null!, null!, null!, null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext();
        http.User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())], "DisplayRegression"));
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        controller.TempData = new TempDataDictionary(http, new MemoryTempDataProvider());
        controller.Url = new TestUrlHelper(controller.ControllerContext);
        return controller;
    }
    private static void AddValidationErrors(Controller controller, EditApplicationViewModel model)
    {
        foreach (var item in model.Displays.Select((row, index) => (row, index)))
        {
            var errors = new List<ValidationResult>();
            Validator.TryValidateObject(item.row, new ValidationContext(item.row), errors, true);
            foreach (var error in errors)
                foreach (var member in error.MemberNames)
                    controller.ModelState.AddModelError($"Displays[{item.index}].{member}", error.ErrorMessage ?? "Invalid display.");
        }
    }
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + message);
        assertions++;
    }
}

sealed class MemoryTempDataProvider : ITempDataProvider
{
    public IDictionary<string, object> LoadTempData(HttpContext context) => new Dictionary<string, object>();
    public void SaveTempData(HttpContext context, IDictionary<string, object> values) { }
}
sealed class TestUrlHelper(ActionContext context) : IUrlHelper
{
    public ActionContext ActionContext => context;
    public string? Action(UrlActionContext context) => "/application-details";
    public string? Content(string? contentPath) => contentPath;
    public bool IsLocalUrl(string? url) => true;
    public string? Link(string? routeName, object? values) => null;
    public string? RouteUrl(UrlRouteContext context) => null;
}
