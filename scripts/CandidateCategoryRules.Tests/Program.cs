using System.Data;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewComponents;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;
using YKBAfife.ViewComponents;

// This executable intentionally accepts only the runner's disposable LocalDB name.
// It never loads application settings or obtains a production connection implicitly.
var connection = args.Length == 2 && args[0] == "--connection"
    ? args[1]
    : Environment.GetEnvironmentVariable("AFIFE_CANDIDATE_TEST_CONNECTION");
if (string.IsNullOrWhiteSpace(connection))
    throw new ArgumentException("Pass --connection for a disposable candidate regression database.");
var connectionSettings = new SqlConnectionStringBuilder(connection);
var allowedLocalTestServer = Environment.GetEnvironmentVariable("AFIFE_TEST_SQL_SERVER");
if (string.IsNullOrWhiteSpace(allowedLocalTestServer))
    allowedLocalTestServer = @"(localdb)\MSSQLLocalDB";
if (!Regex.IsMatch(allowedLocalTestServer, @"^\(localdb\)\\[A-Za-z0-9_-]+$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
    throw new ArgumentException("AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.");
if (!Regex.IsMatch(connectionSettings.InitialCatalog, "^YkbAfifeCandidateRulesTest_[a-f0-9]{32}$") ||
    !string.Equals(connectionSettings.DataSource, allowedLocalTestServer, StringComparison.OrdinalIgnoreCase) ||
    !connectionSettings.IntegratedSecurity)
    throw new ArgumentException("Only the dedicated GUID-suffixed disposable LocalDB is allowed.");

var options = new DbContextOptionsBuilder<AfifeContext>()
    .UseSqlServer(connection, sql => sql.CommandTimeout(180))
    .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>()
    .Options;
await using var context = new AfifeContext(options);
await context.Database.OpenConnectionAsync();
var tests = new RegressionChecks(context);
await tests.RunAsync();

sealed class RegressionChecks(AfifeContext context)
{
    private const string OldChoreographyName = "Yılın En Başarılı Hareket Düzeni (Kareografisi)";
    private const string NewChoreographyName = "Yılın En Başarılı Hareket Tasarımı (Kareografisi)";
    private readonly Guid formId = Guid.NewGuid();
    private readonly Guid juryId = Guid.NewGuid();
    private Guid playId;
    private Dictionary<int, Guid> candidateIds = [];
    private Dictionary<int, int> roleCodes = [];
    private Dictionary<int, Guid> voteIds = [];
    private int assertionCount;

    public async Task RunAsync()
    {
        var migrations = context.Database.GetMigrations().ToArray();
        var baseline = migrations.Single(id => id.EndsWith("_InitialBaseline_v_20260827", StringComparison.Ordinal));
        var updatedRules = migrations.Single(id => id.Contains("_CandidateCategoryRulesUpdated_v_", StringComparison.Ordinal));
        var migrator = context.GetService<IMigrator>();
        await migrator.MigrateAsync(baseline);
        Check(await TextAsync("SELECT CategoryName FROM dbo.AwardCategories WHERE CategoryCode = 1011") == OldChoreographyName,
            "Baseline uses the immutable previous 1011 category label.");
        var baselineTrigger = await ModuleAsync("dbo.TR_Plays_EnsureDefaultAwardCategory");
        var baselineProcedure = await ModuleAsync("dbo.usp_SynchronizeFormCandidates");
        await SeedFormAndVotesAsync();
        await ExecuteAsync("UPDATE dbo.PlayAwardCategories SET IsActive = 0 WHERE PlayId = @play AND AwardCategoryCode IN (1001, 1002)",
            ("@play", playId));
        var beforeUpgrade = await CountsAsync();
        await migrator.MigrateAsync(updatedRules);
        Check(await CountsAsync() == beforeUpgrade, "Up migration preserves Form, candidate and vote row counts.");
        await CheckCandidateStatesAsync(false, false, true, "Up migration preserves existing manual inactive flags");
        Check(await TextAsync("SELECT CategoryName FROM dbo.AwardCategories WHERE CategoryCode = 1011") == NewChoreographyName,
            "Up migration updates category 1011 by code.");
        Check(await ModuleAsync("dbo.TR_Plays_EnsureDefaultAwardCategory") != baselineTrigger,
            "Up migration deploys updated default-category trigger.");
        Check(await ModuleAsync("dbo.usp_SynchronizeFormCandidates") != baselineProcedure,
            "Up migration deploys updated Form candidate procedure.");

        await migrator.MigrateAsync(baseline);
        Check(await CountsAsync() == beforeUpgrade, "Down migration retains all business rows.");
        Check(await TextAsync("SELECT CategoryName FROM dbo.AwardCategories WHERE CategoryCode = 1011") == OldChoreographyName,
            "Down migration restores previous category label.");
        Check(await ModuleAsync("dbo.TR_Plays_EnsureDefaultAwardCategory") == baselineTrigger &&
              await ModuleAsync("dbo.usp_SynchronizeFormCandidates") == baselineProcedure,
            "Down migration restores exact previous procedure and trigger definitions.");
        await CheckCandidateStatesAsync(false, false, true, "Down migration retains manual flags");
        await migrator.MigrateAsync();
        await CheckCandidateStatesAsync(false, false, true, "Reapplying migration retains manual flags");
        Console.WriteLine("PASS: baseline → updated rules → baseline → latest, labels and data preservation.");

        await TestStatusEndpointAndProtectionAsync();
        await TestMetadataAndLifecycleAsync();
        await TestCandidateOrderingAndComponentsAsync();
        await TestPlayReportAsync();
        await TestOptionalCandidateLifecycleAndMultiplicityAsync();
        Console.WriteLine($"PASS: {assertionCount} candidate-category regression assertions.");
    }

    private async Task SeedFormAndVotesAsync()
    {
        await ExecuteAsync("""
            INSERT INTO dbo.Form
            (Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName, TheatreName,
             PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email, Director,
             LeadActress, StageMusic, LightDesign, Choreography, IsActive, IsPublished)
            VALUES
            (@form, N'000001', '2026-09-01', '2026-09-01',
             N'Regression Production', N'Regression Theater', '2026-08-01', N'[]',
             N'Regression Applicant', N'Producer', N'5551234567', N'form@example.invalid',
             N'Regression Director',
             N'[{"Name":"Regression Actress","Role":"Lead"}]',
             N'[{"Name":"Regression Composer"}]', N'[{"Name":"Regression Lighting"}]',
             N'[{"Name":"Regression Choreographer"}]', 1, 1);

            INSERT INTO dbo.Users
            (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished,
             RoleCode, IsActive, IsJuryPresident)
            VALUES (@jury, N'Regression', N'Jury', N'regression.jury',
                N'not-a-real-hash', N'jury@example.invalid', 1, 2, 1, 0);
            """, ("@form", formId), ("@jury", juryId));
        playId = await GuidAsync("SELECT Id FROM dbo.Plays WHERE SourceFormId = @form", ("@form", formId));
        var candidates = await context.PlayAwardCategories.AsNoTracking()
            .Where(candidate => candidate.PlayId == playId).ToArrayAsync();
        candidateIds = candidates.ToDictionary(candidate => candidate.AwardCategoryCode, candidate => candidate.Id);
        roleCodes = candidates.ToDictionary(candidate => candidate.AwardCategoryCode, candidate => candidate.RoleCode);
        Check(candidateIds.Keys.Order().SequenceEqual(new[] { 1001, 1002, 1003, 1009, 1010, 1011 }),
            "Form creates default, director and populated optional-category candidates.");
        foreach (var code in new[] { 1001, 1002, 1003 })
        {
            var voteId = Guid.NewGuid();
            voteIds[code] = voteId;
            await ExecuteAsync("""
                INSERT INTO dbo.JuryVotes
                (Id, PlayAwardCategoryId, CreatedAt, IsPublished, IsActive, Score, JuryId)
                VALUES (@id, @candidate, SYSDATETIME(), 1, 1, 8, @jury)
                """, ("@id", voteId), ("@candidate", candidateIds[code]), ("@jury", juryId));
        }
    }

    private ManagementController Controller()
    {
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!,
            null!, null!, new PlayReportService(context), new CandidateReportService(context), null!,
            null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, juryId.ToString()), new Claim(ClaimTypes.Role, "Admin")], "Regression"))
        };
        http.Request.Headers["X-Requested-With"] = "XMLHttpRequest";
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private async Task TestStatusEndpointAndProtectionAsync()
    {
        var method = typeof(ManagementController).GetMethod(nameof(ManagementController.UpdateCandidateStatus))!;
        var attributeNames = method.GetCustomAttributes(inherit: true).Select(attribute => attribute.GetType().Name).ToArray();
        Check(attributeNames.Contains(nameof(ValidateAntiForgeryTokenAttribute)) && attributeNames.Contains("AdminMutationAuditAttribute"),
            "Status endpoint retains antiforgery and admin audit attributes.");
        foreach (var code in new[] { 1001, 1002 })
        {
            foreach (var active in new[] { true, false })
            {
                context.ChangeTracker.Clear();
                var result = await Controller().UpdateCandidateStatus(candidateIds[code], active, default);
                Check(result is JsonResult, $"Category {code} status endpoint accepts {active}.");
                Check(await BoolAsync("SELECT IsActive FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[code])) == active,
                    $"Category {code} candidate persists actual status {active}.");
                Check(await BoolAsync("SELECT IsActive FROM dbo.JuryVotes WHERE Id = @id", ("@id", voteIds[code])) == active,
                    $"Category {code} votes follow status {active}.");
                Check(await BoolAsync("SELECT IsPublished FROM dbo.Rankings WHERE PlayAwardCategoryId = @id", ("@id", candidateIds[code])) == active,
                    $"Category {code} rankings eligibility follows status {active}.");
            }
            var deleteResult = await Controller().DeleteCandidate(candidateIds[code], default);
            Check(deleteResult is BadRequestObjectResult, $"Category {code} deletion remains protected.");
            var editResult = await Controller().EditCandidate(candidateIds[code], new EditCandidateViewModel
            {
                Id = candidateIds[code], Candidate = "Forbidden identity change", IsActive = true
            }, default);
            Check(editResult is BadRequestResult, $"Category {code} identity editing remains protected.");
            await ExpectSqlErrorAsync(51307, "DELETE FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[code]));
        }
        var auditRows = await context.AdminLogs.AsNoTracking()
            .Where(log => log.TableName == "PlayAwardCategories" && log.OperationType == "Update")
            .Select(log => new { log.OldValues, log.NewValues }).ToArrayAsync();
        Check(auditRows.Any(log => HasFlagTransition(log.OldValues, log.NewValues, candidateIds[1001], true, false)) &&
              auditRows.Any(log => HasFlagTransition(log.OldValues, log.NewValues, candidateIds[1002], false, true)),
            "SQL audit records candidate status old/new values in both directions.");
        context.ChangeTracker.Clear();
        Console.WriteLine("PASS: 1001/1002 endpoint toggles, votes, rankings, audit and identity/delete protection.");
    }

    private async Task TestMetadataAndLifecycleAsync()
    {
        await ExecuteAsync("UPDATE dbo.Plays SET PlayName = N'Regression Renamed Production' WHERE Id = @play", ("@play", playId));
        await CheckCandidateStatesAsync(false, false, true, "Play name change preserves manual statuses");
        await ExecuteAsync("UPDATE dbo.Plays SET TheaterName = N'Regression Renamed Theater' WHERE Id = @play", ("@play", playId));
        await CheckCandidateStatesAsync(false, false, true, "Theater name change preserves manual statuses");
        Check(await TextAsync("SELECT Candidate FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1001])) == "Regression Renamed Theater",
            "Default candidate display follows theater name without changing identity.");
        await ExecuteAsync("UPDATE dbo.Form SET Director = N'Regression Renamed Director' WHERE Id = @form", ("@form", formId));
        await CheckCandidateStatesAsync(false, false, true, "Form director change preserves manual statuses");
        Check(await TextAsync("SELECT Candidate FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1002])) == "Regression Renamed Director",
            "Director display updates without replacing its candidate ID.");
        await ExecuteAsync("UPDATE dbo.Form SET ApplicantRole = N'Updated unrelated role' WHERE Id = @form; EXEC dbo.usp_SynchronizeFormsToPlays;",
            ("@form", formId));
        await CheckCandidateStatesAsync(false, false, true, "Unrelated Form changes/full synchronization preserve manual statuses");

        await ExecuteAsync("UPDATE dbo.Form SET IsActive = 0 WHERE Id = @form", ("@form", formId));
        Check(!await BoolAsync("SELECT IsActive FROM dbo.Plays WHERE Id = @id", ("@id", playId)), "Inactive Form deactivates Play.");
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.PlayAwardCategories WHERE PlayId = @play AND (IsPublished = 1 OR IsActive = 1)",
            ("@play", playId)) == 0, "Inactive Form retires all candidate flags.");
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.JuryVotes vote JOIN dbo.PlayAwardCategories candidate ON candidate.Id = vote.PlayAwardCategoryId WHERE candidate.PlayId = @play AND (vote.IsPublished = 1 OR vote.IsActive = 1)",
            ("@play", playId)) == 0, "Inactive Form retires all vote flags.");
        foreach (var code in new[] { 1001, 1002, 1003 })
            Check(await BoolAsync("SELECT WasActive FROM dbo.FormLifecycleStates WHERE EntityName = N'PlayAwardCategory' AND EntityId = @id AND IsPublished = 1",
                ("@id", candidateIds[code])) == (code == 1003), $"Lifecycle snapshot captures actual {code} manual state.");
        await ExecuteAsync("UPDATE dbo.Form SET IsActive = 1 WHERE Id = @form", ("@form", formId));
        await CheckCandidateStatesAsync(false, false, true, "Form reactivation restores manual statuses from snapshots");
        Check(await BoolAsync("SELECT IsActive FROM dbo.Plays WHERE Id = @id", ("@id", playId)), "Form reactivation restores Play.");
        foreach (var code in new[] { 1001, 1002, 1003 })
        {
            Check(await BoolAsync("SELECT IsPublished FROM dbo.JuryVotes WHERE Id = @id", ("@id", voteIds[code])), $"Vote {code} publication restored.");
            Check(await BoolAsync("SELECT IsActive FROM dbo.JuryVotes WHERE Id = @id", ("@id", voteIds[code])) == (code == 1003),
                $"Vote {code} restores its original status.");
            Check(await IntAsync("SELECT RoleCode FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[code])) == roleCodes[code],
                $"RoleCode {code} remains stable.");
        }
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.FormLifecycleStates WHERE FormId = @form AND IsPublished = 1", ("@form", formId)) == 0,
            "Successful restore retires lifecycle snapshots.");
        Check(await BoolAsync("SELECT IsPublished FROM dbo.Rankings WHERE PlayAwardCategoryId = @id", ("@id", candidateIds[1003])),
            "Active other-category ranking is restored.");
        Check(!await BoolAsync("SELECT IsPublished FROM dbo.Rankings WHERE PlayAwardCategoryId = @id", ("@id", candidateIds[1001])),
            "Manually inactive default candidate stays out of rankings after restore.");
        Console.WriteLine("PASS: metadata synchronization and Form passive/active restoration preserve manual states and identities.");
    }

    private async Task TestCandidateOrderingAndComponentsAsync()
    {
        var service = new CandidateReportService(context);
        var ascending = await service.GetPageAsync(new CandidateTableQuery { PlayId = playId });
        var descending = await service.GetPageAsync(new CandidateTableQuery { PlayId = playId, SortBy = CandidateSortColumns.Category, SortDirection = "desc" });
        var expectedCodes = new[] { 1001, 1002, 1003, 1009, 1010, 1011 };
        Check(ascending.Rows.Select(row => row.CategoryCode).SequenceEqual(expectedCodes), "Candidate table category ascending sort is numeric.");
        Check(descending.Rows.Select(row => row.CategoryCode).SequenceEqual(expectedCodes.Reverse()), "Candidate table category descending sort is numeric.");
        Check(ascending.Categories.Select(category => category.CategoryCode).SequenceEqual(ascending.Categories.Select(category => category.CategoryCode).Order()),
            "Candidate filter options are in CategoryCode order.");
        var exported = await service.GetExportRowsAsync(new CandidateTableQuery { PlayId = playId });
        Check(exported.Select(row => row.Id).SequenceEqual(ascending.Rows.Select(row => row.Id)), "Export uses the same numeric category ordering.");
        var table = CandidateComplexTableFactory.Create(ascending);
        Check(table.SelectFilter!.Options[0].Text == "Tüm Adaylar", "All-candidates filter remains the first option.");
        foreach (var code in new[] { 1001, 1002 })
        {
            var row = table.Tabs.Single().Rows.Single(row => row.Id == $"candidate-{candidateIds[code]:N}");
            Check(!row.Cells.Last().ToggleDisabled && !row.Cells.Last().ToggleChecked,
                $"Table toggle {code} is enabled and shows its real inactive state.");
            Check(string.IsNullOrEmpty(row.DeleteUrl), $"Table delete action {code} remains absent.");
        }
        var component = new AddCandidateViewComponent(context)
        {
            ViewComponentContext = new ViewComponentContext { ViewContext = new Microsoft.AspNetCore.Mvc.Rendering.ViewContext() }
        };
        var result = (ViewViewComponentResult)await component.InvokeAsync(playId);
        var model = (AddCandidateViewModel)result.ViewData!.Model!;
        Check(model.AwardCategories.Select(option => option.CategoryCode).SequenceEqual(model.AwardCategories.Select(option => option.CategoryCode).Order()),
            "Add Candidate options sort by numeric CategoryCode.");
        Check(!model.AwardCategories.Any(option => option.CategoryCode is 1001 or 1002), "Add Candidate excludes system-managed identities.");
        Check(model.AwardCategories.Single(option => option.CategoryCode == 1011).CategoryName == NewChoreographyName,
            "Add Candidate component receives the new choreography label.");
        Console.WriteLine("PASS: candidate numeric sorting/export, dropdown models and actual enabled toggle state.");
    }

    private async Task TestPlayReportAsync()
    {
        var when = new DateTime(2026, 10, 1, 12, 0, 0);
        var rows = new[]
        {
            new PlayFixture("Nereid", "Ocean", false, when.AddDays(-3), true),
            new PlayFixture("Zephyr", "Wind", false, when, true),
            new PlayFixture("Atlas", "Mountain", false, when, true),
            new PlayFixture("Atlas", "Desert", false, when, true),
            new PlayFixture("Nimbus", "Cloud", false, null, true),
            new PlayFixture("Hamlet", "Danish Stage", false, when.AddDays(-4), false),
            new PlayFixture("Hamlet!", "Danish Stage", false, when.AddDays(-1), false),
            new PlayFixture("Violet", "Iris", true, when.AddDays(7), false),
            new PlayFixture("Coral", "Reef", true, when.AddDays(5), false),
            new PlayFixture("Eclipse", "Moon", true, when.AddDays(4), false),
            new PlayFixture("Ivory", "Savannah", true, when.AddDays(3), false),
            new PlayFixture("Quartz", "Crystal", true, when.AddDays(2), false),
            new PlayFixture("Solstice", "Sun", true, when.AddDays(1), false),
            new PlayFixture("Obsidian", "Volcano", true, null, false)
        };
        foreach (var row in rows)
            await ExecuteAsync("""
                INSERT INTO dbo.Plays
                (Id, PlayName, TheaterName, StatusCode, CreatedAt, UpdatedAt, IsPublished,
                 Slug, JuriOylamaStatus, KunyeGirisStatus, RecordType, IsActive)
                VALUES (@id, @name, @theater, 6, @created, @updated, 1, @slug, 1, 0, @admin, 1)
                """, ("@id", row.Id), ("@name", row.Name), ("@theater", "SORTFIXTURE " + row.Theater),
                ("@created", row.Created), ("@updated", row.New ? row.Created : when.AddDays(20)),
                ("@slug", "sort-" + row.Id.ToString("N")), ("@admin", row.Admin));
        var service = new PlayReportService(context);
        var first = await service.GetPageAsync(new PlayTableQuery { Search = "SORTFIXTURE" });
        var second = await service.GetPageAsync(new PlayTableQuery { Search = "SORTFIXTURE", Page = 2 });
        var all = first.Rows.Concat(second.Rows).ToArray();
        Check(first.SortBy == PlaySortColumns.CreatedAt && first.SortDirection == "desc", "Default report sort is createdAt descending.");
        Check(first.TotalCount == rows.Length && first.Rows.Count == 10 && second.Rows.Count == 4,
            "Search filter is applied before two-page pagination.");
        Check(all.Select(row => row.PlayId).Distinct().Count() == rows.Length, "Pagination returns every row exactly once.");
        var newRows = all.Where(row => row.IsNew).ToArray();
        var similar = all.Where(row => !row.IsNew && row.HasSimilarPlay).ToArray();
        var normal = all.Where(row => !row.IsNew && !row.HasSimilarPlay).ToArray();
        Check(newRows.Length == 5 && similar.Length == 2 && normal.Length == 7, "Fixtures exercise new, similar and ordinary priority groups.");
        Check(all.Select(row => row.PlayId).SequenceEqual(newRows.Concat(similar).Concat(normal).Select(row => row.PlayId)),
            "New rows precede similar rows, which precede normal rows across page boundaries.");
        foreach (var group in new[] { newRows, similar, normal })
        {
            Check(group.Select(row => row.CreatedAt).SequenceEqual(group.Select(row => row.CreatedAt).OrderByDescending(date => date.HasValue).ThenByDescending(date => date)),
                "Each priority group uses descending dates with nulls last.");
        }
        Check(newRows.Where(row => row.CreatedAt == when).Select(row => row.PlayName).SequenceEqual(new[] { "Atlas", "Atlas", "Zephyr" }),
            "Equal createdAt values use play-name tiebreaker.");
        var ids = await GuidsAsync("SELECT Id FROM dbo.Plays WHERE PlayName = N'Atlas' AND TheaterName LIKE N'SORTFIXTURE%' ORDER BY Id");
        Check(newRows.Where(row => row.PlayName == "Atlas").Select(row => row.PlayId).SequenceEqual(ids), "Equal dates and names use database Guid ordering.");
        var changed = await service.GetPageAsync(new PlayTableQuery { Search = "SORTFIXTURE", SortBy = PlaySortColumns.PlayName, SortDirection = "asc" });
        Check(changed.Rows.Take(5).Select(row => row.PlayName).SequenceEqual(new[] { "Atlas", "Atlas", "Nereid", "Nimbus", "Zephyr" }),
            "Explicit name sort works within priority groups.");
        var invalid = await service.GetPageAsync(new PlayTableQuery { Search = "SORTFIXTURE", SortBy = "invalid", SortDirection = "asc" });
        Check(invalid.SortBy == PlaySortColumns.CreatedAt && invalid.SortDirection == "desc" && invalid.Rows.Select(row => row.PlayId).SequenceEqual(first.Rows.Select(row => row.PlayId)),
            "Invalid sort request falls back to deterministic newest-first ordering.");
        var admins = await service.GetPageAsync(new PlayTableQuery { Search = "SORTFIXTURE", RecordType = true });
        Check(admins.TotalCount == 7 && admins.Rows.All(row => row.RecordType), "Record type filtering precedes ordering and pagination.");
        Console.WriteLine("PASS: grouped newest-first default sort, filters, pagination, null dates and deterministic ties.");
    }

    private async Task CheckCandidateStatesAsync(bool defaultActive, bool directorActive, bool actressActive, string label)
    {
        foreach (var (code, active) in new[] { (1001, defaultActive), (1002, directorActive), (1003, actressActive) })
        {
            Check(await BoolAsync("SELECT IsActive FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[code])) == active, $"{label}: {code}.");
            Check(await BoolAsync("SELECT IsPublished FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[code])), $"{label}: {code} remains published.");
        }
    }

    private async Task TestOptionalCandidateLifecycleAndMultiplicityAsync()
    {
        await ExpectSqlErrorAsync(51306, """
            INSERT INTO dbo.PlayAwardCategories
            (Id, PlayId, CreatedAt, IsPublished, IsActive, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
            VALUES (NEWID(), @play, SYSDATETIME(), 1, 1, N'Forbidden second director', 1002, 1, NULL, @role)
            """, ("@play", playId), ("@role", roleCodes[1002]));
        await ExpectSqlErrorAsync(51302, "UPDATE dbo.PlayAwardCategories SET Candidate = N'Forbidden default identity' WHERE Id = @id",
            ("@id", candidateIds[1001]));
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.PlayAwardCategories WHERE PlayId = @play AND AwardCategoryCode IN (1001, 1002) AND IsCurrent = 1",
            ("@play", playId)) == 2, "1001/1002 remain single-current-candidate categories after rejected writes.");

        await ExecuteAsync("UPDATE dbo.PlayAwardCategories SET IsActive = 0 WHERE Id = @id", ("@id", candidateIds[1009]));
        await ExecuteAsync("UPDATE dbo.Form SET StageMusic = NULL WHERE Id = @form", ("@form", formId));
        Check(!await BoolAsync("SELECT IsPublished FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1009])) &&
              !await BoolAsync("SELECT IsCurrent FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1009])),
            "Removing an optional Form source retires its candidate without deleting the row.");
        await ExecuteAsync("""
            UPDATE dbo.Form
            SET StageMusic = N'[{"Name":"Regression Composer"}]',
                StageDesign = N'[{"Name":"New Regression Designer"}]'
            WHERE Id = @form
            """, ("@form", formId));
        Check(await BoolAsync("SELECT IsPublished FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1009])) &&
              await BoolAsync("SELECT IsCurrent FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1009])) &&
              await BoolAsync("SELECT IsActive FROM dbo.PlayAwardCategories WHERE Id = @id", ("@id", candidateIds[1009])),
            "Re-added retired source becomes active/current again with its existing identity.");
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.PlayAwardCategories WHERE PlayId = @play AND AwardCategoryCode = 1007 AND IsActive = 1 AND IsPublished = 1 AND IsCurrent = 1",
            ("@play", playId)) == 1, "A newly populated optional Form category starts active/current.");
        await CheckCandidateStatesAsync(false, false, true, "Optional category changes preserve unrelated manual statuses");

        await ExecuteAsync("""
            INSERT INTO dbo.PlayAwardCategories
            (Id, PlayId, CreatedAt, IsPublished, IsActive, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
            VALUES (NEWID(), @play, SYSDATETIME(), 1, 1, N'Regression Actress', 1003, 1, N'Alternate role', 9000)
            """, ("@play", playId));
        Check(await IntAsync("SELECT COUNT(*) FROM dbo.PlayAwardCategories WHERE PlayId = @play AND AwardCategoryCode = 1003 AND Candidate = N'Regression Actress' AND IsPublished = 1 AND IsCurrent = 1",
            ("@play", playId)) == 2, "Multiple current candidates with different RoleCode remain allowed for person categories.");
        var expected = await GuidsAsync("SELECT Id FROM dbo.PlayAwardCategories WHERE PlayId = @play AND IsPublished = 1 ORDER BY AwardCategoryCode, Candidate, Id",
            ("@play", playId));
        var export = await new CandidateReportService(context).GetExportRowsAsync(new CandidateTableQuery { PlayId = playId });
        Check(export.Select(row => row.Id).SequenceEqual(expected), "Category sort ties use candidate name and stable ID, including same-name distinct roles.");
        Console.WriteLine("PASS: single-candidate protection, optional-source removal/re-add, new categories and duplicate-name role slots.");
    }

    private static bool HasFlagTransition(string? oldJson, string? newJson, Guid id, bool oldFlag, bool newFlag)
    {
        if (oldJson is null || newJson is null) return false;
        using var before = JsonDocument.Parse(oldJson);
        using var after = JsonDocument.Parse(newJson);
        return Has(before.RootElement, oldFlag) && Has(after.RootElement, newFlag);
        bool Has(JsonElement root, bool flag) => root.EnumerateArray().Any(row =>
            row.TryGetProperty("Id", out var key) && key.GetGuid() == id &&
            row.TryGetProperty("IsActive", out var value) && value.GetBoolean() == flag);
    }

    private async Task<(int Forms, int Candidates, int Votes)> CountsAsync() =>
        (await IntAsync("SELECT COUNT(*) FROM dbo.Form"),
         await IntAsync("SELECT COUNT(*) FROM dbo.PlayAwardCategories"),
         await IntAsync("SELECT COUNT(*) FROM dbo.JuryVotes"));

    private async Task<string> ModuleAsync(string name) => await TextAsync("SELECT OBJECT_DEFINITION(OBJECT_ID(@name))", ("@name", name));
    private async Task<bool> BoolAsync(string sql, params (string Name, object? Value)[] args) => Convert.ToBoolean(await ScalarAsync(sql, args));
    private async Task<int> IntAsync(string sql, params (string Name, object? Value)[] args) => Convert.ToInt32(await ScalarAsync(sql, args));
    private async Task<string> TextAsync(string sql, params (string Name, object? Value)[] args) => (string)(await ScalarAsync(sql, args))!;
    private async Task<Guid> GuidAsync(string sql, params (string Name, object? Value)[] args) => (Guid)(await ScalarAsync(sql, args))!;
    private async Task<object?> ScalarAsync(string sql, params (string Name, object? Value)[] args)
    {
        await using var command = Command(sql, args);
        var value = await command.ExecuteScalarAsync();
        return value is DBNull ? null : value;
    }
    private async Task ExecuteAsync(string sql, params (string Name, object? Value)[] args)
    {
        await using var command = Command(sql, args);
        await command.ExecuteNonQueryAsync();
    }
    private async Task<Guid[]> GuidsAsync(string sql, params (string Name, object? Value)[] args)
    {
        await using var command = Command(sql, args);
        await using var reader = await command.ExecuteReaderAsync();
        var values = new List<Guid>();
        while (await reader.ReadAsync()) values.Add(reader.GetGuid(0));
        return values.ToArray();
    }
    private SqlCommand Command(string sql, params (string Name, object? Value)[] args)
    {
        var command = ((SqlConnection)context.Database.GetDbConnection()).CreateCommand();
        command.CommandText = sql;
        command.CommandTimeout = 180;
        foreach (var (name, value) in args) command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }
    private async Task ExpectSqlErrorAsync(int number, string sql, params (string Name, object? Value)[] args)
    {
        try { await ExecuteAsync(sql, args); }
        catch (SqlException error) when (error.Number == number) { assertionCount++; return; }
        throw new InvalidOperationException($"Expected SQL error {number} was not raised.");
    }
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException("REGRESSION FAILED: " + message);
        assertionCount++;
    }
    private sealed record PlayFixture(string Name, string Theater, bool Admin, DateTime? Created, bool New)
    {
        public Guid Id { get; } = Guid.NewGuid();
    }
}
