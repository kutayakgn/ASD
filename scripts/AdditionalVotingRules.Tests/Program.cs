using System.Data;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using AdditionalVotingRules.Tests;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;
using YkbAfife.Domain.Model.Data.JuryVoting;

var connection = args.Length == 2 && args[0] == "--connection" ? args[1] : null;
if (string.IsNullOrWhiteSpace(connection))
    throw new ArgumentException("Pass --connection for the runner's disposable additional voting regression database.");
var settings = new SqlConnectionStringBuilder(connection);
if (!Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeAdditionalVotingTest_[a-f0-9]{32}$") ||
    !string.Equals(settings.DataSource, @"(localdb)\MSSQLLocalDB", StringComparison.OrdinalIgnoreCase) ||
    !settings.IntegratedSecurity)
    throw new ArgumentException("Only the dedicated GUID-suffixed disposable LocalDB is allowed.");

await new RegressionChecks(connection).RunAsync();

sealed class RegressionChecks(string connection)
{
    private int assertions;
    private Guid permissionId;
    private static DateOnly Today => DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,
        TimeZoneInfo.FindSystemTimeZoneById(OperatingSystem.IsWindows() ? "Turkey Standard Time" : "Europe/Istanbul")));

    private AfifeContext Context() => new(new DbContextOptionsBuilder<AfifeContext>()
        .UseSqlServer(connection, sql => sql.CommandTimeout(120))
        .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options);

    public async Task RunAsync()
    {
        await using (var context = Context()) await context.Database.MigrateAsync();
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages') AND name = N'IX_AdditionalVotingUsages_Jury_Play' AND is_unique = 0") == 1,
            "Migration installs nonunique published usage history index.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages') AND name = N'UX_AdditionalVotingUsages_OneTime' AND is_unique = 1") == 0,
            "Migration removes the one-use uniqueness restriction.");
        var fixture = await SeedFixtureAsync();
        await TestFirstVoteAsync(fixture);
        permissionId = Guid.NewGuid();
        await ExecuteAsync("""
            INSERT INTO dbo.AdditionalVotings
            (Id, StartDate, EndDate, AppliesToAllJuries, AppliesToAllPlays, CreatedAt, IsActive, IsPublished)
            VALUES (@id, @start, @end, 1, 1, SYSDATETIME(), 1, 1)
            """, ("@id", permissionId), ("@start", Today.AddDays(-1).ToDateTime(TimeOnly.MinValue)),
            ("@end", Today.AddDays(1).ToDateTime(TimeOnly.MinValue)));
        await TestRepeatedEditsAndLogsAsync(fixture);
        await TestEligibilityAsync(fixture);
        await TestLockedFeesAsync(fixture);
        await TestConcurrentFirstFeeAsync();
        await TestAdminCorrectionAsync(fixture);
        await TestRollbackAsync(fixture);
        Console.WriteLine($"PASS: {assertions} additional voting regression assertions using actual kit service methods.");
    }

    private async Task TestFirstVoteAsync(Fixture fixture)
    {
        foreach (var fee in new int?[] { null, 0, -1, 100000 })
        {
            var before = await MutationSnapshotAsync(fixture);
            var result = await SaveAsync(fixture, fee, 3);
            Check(result == JuryVotingSaveVoteResult.InvalidTicketFee,
                $"Initial vote rejects invalid/missing ticket fee {fee?.ToString() ?? "null"}; actual result: {result}.");
            Check(await MutationSnapshotAsync(fixture) == before, "Invalid first fee leaves votes, fees and usages untouched.");
        }
        Check(await SaveAsync(fixture, 100, 3) == JuryVotingSaveVoteResult.Success,
            "Normal first vote with valid first ticket fee works without additional permission.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.AdditionalVotingUsages WHERE JuryId = @jury AND PlayId = @play",
            ("@jury", fixture.JuryId), ("@play", fixture.PlayId)) == 0, "Normal initial voting does not consume additional history.");
        var detail = await DetailAsync(fixture);
        Check(!detail.IsTicketFeeEditable && !detail.CanEditExistingVotes && !detail.CanSubmit,
            "A saved fee and existing vote are locked outside an additional window.");
        Check(await SaveAsync(fixture, null, 4) == JuryVotingSaveVoteResult.AdditionalVotingNotAvailable,
            "Existing vote cannot change outside an additional window.");
        Console.WriteLine("PASS: initial vote and required first fee validation.");
    }

    private async Task TestRepeatedEditsAndLogsAsync(Fixture fixture)
    {
        // A preexisting event must not hide or consume the active permission.
        await ExecuteAsync("""
            INSERT INTO dbo.AdditionalVotingUsages
            (Id, AdditionalVotingId, JuryId, PlayId, UsageType, UsedAt, CreatedAt, IsActive, IsPublished)
            VALUES (NEWID(), @permission, @jury, @play, 1, SYSDATETIME(), SYSDATETIME(), 1, 1)
            """, ("@permission", permissionId), ("@jury", fixture.JuryId), ("@play", fixture.PlayId));
        var detail = await DetailAsync(fixture);
        Check(detail.AdditionalVotingId == permissionId && detail.CanEditExistingVotes && detail.CanSubmit,
            "An earlier usage event does not consume eligibility or lock existing vote cards.");
        Check(!detail.IsTicketFeeEditable && detail.AwardCategories.Count == 3 && detail.AwardCategories.All(card => card.IsEditable),
            "Active permission enables votes while keeping the saved ticket fee locked.");
        var feeBefore = await TicketSnapshotAsync(fixture);
        const int edits = 24;
        for (var i = 0; i < edits; i++)
        {
            var score = i % 2 == 0 ? 4 : 7;
            Check(await SaveAsync(fixture, i % 3 == 0 ? 100 : null, score) == JuryVotingSaveVoteResult.Success,
                $"The same permission accepts consecutive vote edit {i + 1}.");
            Check(await NumberAsync("SELECT Score FROM dbo.JuryVotes WHERE JuryId = @jury AND PlayAwardCategoryId = @candidate AND IsActive = 1 AND IsPublished = 1",
                ("@jury", fixture.JuryId), ("@candidate", fixture.CandidateId)) == score, "Latest vote persists after each update.");
        }
        Check(await TicketSnapshotAsync(fixture) == feeBefore, "Repeated vote edits never rewrite saved ticket fee or its metadata.");
        Check(await UsageCountAsync(fixture) == edits + 1, "Each successful additional vote update appends a separate usage event.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.JuryVotes WHERE JuryId = @jury AND PlayAwardCategoryId = @candidate",
            ("@jury", fixture.JuryId), ("@candidate", fixture.CandidateId)) == 1, "Edits update the same vote without duplicate logical records.");
        await using (var context = Context())
        {
            var logs = await context.JuryLogs.AsNoTracking().Where(log => log.JuryId == fixture.JuryId &&
                log.PlayId == fixture.PlayId && log.OperationType == "AdditionalVoteUpdate" && log.IsSuccessful).ToArrayAsync();
            Check(logs.Length == edits, "Every update writes an independent successful jury log.");
            Check(logs.All(log => log.AdditionalVotingId == permissionId && log.AdditionalVotingUsageId.HasValue &&
                log.OldTicketFee == 100 && log.NewTicketFee == 100 && log.AffectedVoteCount == 1),
                "Logs retain permission, event ID and unchanged saved fee.");
            Check(logs.All(log => DifferentScores(log.OldVotesJson, log.NewVotesJson)),
                "Logs capture distinct old and new vote values for every update.");
            var report = await new AdditionalVotingReportService(context).GetPageAsync(new AdditionalVotingTableQuery());
            var row = report.Rows.Single(row => row.Id == permissionId);
            Check(row.VoteUpdateUserCount == 1 && row.FirstVoteUserCount == 0,
                "Repeated usages still count one distinct updated jury in additional-voting reports.");
        }
        var snapshot = await MutationSnapshotAsync(fixture);
        Check(await SaveAsync(fixture, null, 7) == JuryVotingSaveVoteResult.NoChanges, "No-op request remains a no-op.");
        Check(await MutationSnapshotAsync(fixture) == snapshot, "No-op request creates no additional usage or vote/fee writes.");
        Console.WriteLine("PASS: 24 repeated edits, prior usage eligibility, logs and distinct-jury reports.");
    }

    private async Task TestEligibilityAsync(Fixture fixture)
    {
        foreach (var (description, sql) in new[]
        {
            ("expired", "UPDATE dbo.AdditionalVotings SET StartDate = @past, EndDate = @yesterday WHERE Id = @id"),
            ("future", "UPDATE dbo.AdditionalVotings SET StartDate = @tomorrow, EndDate = @future WHERE Id = @id"),
            ("inactive", "UPDATE dbo.AdditionalVotings SET IsActive = 0 WHERE Id = @id"),
            ("unpublished", "UPDATE dbo.AdditionalVotings SET IsPublished = 0 WHERE Id = @id"),
            ("jury out of scope", "UPDATE dbo.AdditionalVotings SET AppliesToAllJuries = 0 WHERE Id = @id"),
            ("play out of scope", "UPDATE dbo.AdditionalVotings SET AppliesToAllPlays = 0 WHERE Id = @id")
        })
        {
            await ResetPermissionAsync();
            await ExecuteAsync(sql, ("@id", permissionId), ("@past", Today.AddDays(-3).ToDateTime(TimeOnly.MinValue)),
                ("@yesterday", Today.AddDays(-1).ToDateTime(TimeOnly.MinValue)),
                ("@tomorrow", Today.AddDays(1).ToDateTime(TimeOnly.MinValue)), ("@future", Today.AddDays(3).ToDateTime(TimeOnly.MinValue)));
            var detail = await DetailAsync(fixture);
            Check(!detail.AdditionalVotingId.HasValue && !detail.CanEditExistingVotes && !detail.IsTicketFeeEditable,
                $"Detail rejects {description} permission and retains fee lock.");
            var before = await MutationSnapshotAsync(fixture);
            Check(await SaveAsync(fixture, null, 5) == JuryVotingSaveVoteResult.AdditionalVotingNotAvailable,
                $"API rejects edit with {description} permission.");
            Check(await MutationSnapshotAsync(fixture) == before, $"Rejected {description} edit has no vote/fee/usage mutation.");
        }
        await ResetPermissionAsync();
        await ExecuteAsync("""
            UPDATE dbo.AdditionalVotings SET AppliesToAllJuries = 0, AppliesToAllPlays = 0 WHERE Id = @id;
            INSERT INTO dbo.AdditionalVotingJuries (Id, AdditionalVotingId, JuryId, CreatedAt, IsActive, IsPublished)
            VALUES (NEWID(), @id, @jury, SYSDATETIME(), 1, 1);
            INSERT INTO dbo.AdditionalVotingPlays (Id, AdditionalVotingId, PlayId, CreatedAt, IsActive, IsPublished)
            VALUES (NEWID(), @id, @play, SYSDATETIME(), 1, 1);
            """, ("@id", permissionId), ("@jury", fixture.JuryId), ("@play", fixture.PlayId));
        Check((await DetailAsync(fixture)).AdditionalVotingId == permissionId,
            "Explicit active jury/play scope grants eligibility despite existing usages.");
        Check(await SaveAsync(fixture, null, 6) == JuryVotingSaveVoteResult.Success, "Explicit scope permits another edit.");
        foreach (var (table, active) in new[] { ("AdditionalVotingJuries", false), ("AdditionalVotingPlays", false) })
        {
            await ExecuteAsync($"UPDATE dbo.{table} SET IsActive = @active WHERE AdditionalVotingId = @id",
                ("@active", active), ("@id", permissionId));
            Check(await SaveAsync(fixture, null, 8) == JuryVotingSaveVoteResult.AdditionalVotingNotAvailable,
                $"Inactive {table} membership does not grant scope.");
            await ExecuteAsync($"UPDATE dbo.{table} SET IsActive = 1 WHERE AdditionalVotingId = @id", ("@id", permissionId));
        }
        await ResetPermissionAsync();
        Console.WriteLine("PASS: date, publication, active status and jury/play scope constraints.");
    }

    private async Task TestLockedFeesAsync(Fixture fixture)
    {
        var before = await MutationSnapshotAsync(fixture);
        Check(await SaveAsync(fixture, 101, 9) == JuryVotingSaveVoteResult.TicketFeeAlreadySaved,
            "Active additional voting never permits replacing the initial ticket fee.");
        Check(await MutationSnapshotAsync(fixture) == before, "Tampered fee causes whole request rejection before vote/usage mutation.");
        var feeId = await FeeIdAsync(fixture);
        Check(await SaveAsync(fixture, null, 9, Guid.NewGuid()) == JuryVotingSaveVoteResult.ConcurrencyConflict,
            "Stale fee identity is still rejected.");
        Check(await MutationSnapshotAsync(fixture) == before, "Stale fee ID cannot mutate votes, fee or usage history.");
        await ExecuteAsync("UPDATE dbo.JuryGameTicketFees SET TicketFee = 123.45 WHERE Id = @fee", ("@fee", feeId));
        var fractionalBefore = await TicketSnapshotAsync(fixture);
        Check(await SaveAsync(fixture, 123, 8) == JuryVotingSaveVoteResult.Success,
            "Legacy client's same truncated displayed fee is accepted for vote-only update.");
        Check(await TicketSnapshotAsync(fixture) == fractionalBefore, "Legacy decimal ticket fee is preserved exactly, not overwritten by integer display.");
        Check(await SaveAsync(fixture, null, 9) == JuryVotingSaveVoteResult.Success, "Omitted locked fee permits another vote update.");
        Check(await TicketSnapshotAsync(fixture) == fractionalBefore, "Omitted locked fee retains all fee metadata.");
        await ExecuteAsync("UPDATE dbo.JuryGameTicketFees SET IsPublished = 0 WHERE Id = @fee", ("@fee", feeId));
        var detail = await DetailAsync(fixture);
        Check(!detail.IsTicketFeeEditable && detail.TicketFeeId == feeId && detail.TicketFee == 123,
            "An unpublished historical fee still locks fee entry and retains its identity/value.");
        var unpublishedBefore = await TicketSnapshotAsync(fixture);
        Check(await SaveAsync(fixture, 888, 8) == JuryVotingSaveVoteResult.TicketFeeAlreadySaved,
            "Unpublished historical fee cannot be bypassed by replacing it.");
        Check(await SaveAsync(fixture, null, 8) == JuryVotingSaveVoteResult.Success,
            "Vote-only update remains possible with an unpublished saved fee.");
        Check(await TicketSnapshotAsync(fixture) == unpublishedBefore,
            "Vote-only save neither republishes nor rewrites historical fee.");
        await ExecuteAsync("UPDATE dbo.JuryGameTicketFees SET IsPublished = 1 WHERE Id = @fee", ("@fee", feeId));
        Console.WriteLine("PASS: saved/omitted/fractional/unpublished fees and stale/tampered request guards.");
    }

    private async Task TestConcurrentFirstFeeAsync()
    {
        var fixture = await SeedFixtureAsync();
        // Construct both requests before either transaction starts: both are
        // legitimate first submissions, without a fee identity yet.
        var requestA = Request(fixture, 111, 3, null, null);
        var requestB = Request(fixture, 222, 7, null, null);
        await using var contextA = Context();
        await using var contextB = Context();
        var serviceA = Service(contextA);
        var serviceB = Service(contextB);
        var outcomes = await Task.WhenAll(serviceA.SaveVoteAsync(fixture.JuryId, requestA), serviceB.SaveVoteAsync(fixture.JuryId, requestB));
        Check(outcomes.Count(result => result == JuryVotingSaveVoteResult.Success) == 1,
            $"Concurrent first submissions save only one fee and one vote transaction ({string.Join(", ", outcomes)}).");
        Check(outcomes.All(result => result is JuryVotingSaveVoteResult.Success or JuryVotingSaveVoteResult.ConcurrencyConflict
                or JuryVotingSaveVoteResult.TicketFeeAlreadySaved),
            "The losing concurrent submission returns a controlled conflict/saved-fee result, not an unexpected error.");
        Check(await NumberAsync("SELECT COUNT(*) FROM dbo.JuryGameTicketFees WHERE UserId = @jury AND PlayId = @play",
            ("@jury", fixture.JuryId), ("@play", fixture.PlayId)) == 1, "Concurrent first submissions retain exactly one fee row.");
        var fee = await NumberAsync("SELECT CONVERT(int, TicketFee) FROM dbo.JuryGameTicketFees WHERE UserId = @jury AND PlayId = @play",
            ("@jury", fixture.JuryId), ("@play", fixture.PlayId));
        var score = await NumberAsync("SELECT Score FROM dbo.JuryVotes WHERE JuryId = @jury AND PlayAwardCategoryId = @candidate",
            ("@jury", fixture.JuryId), ("@candidate", fixture.CandidateId));
        Check((fee == 111 && score == 3) || (fee == 222 && score == 7), "Winner's score and first fee commit atomically.");
        Check(await NumberAsync("""
            SELECT COUNT(*) FROM dbo.JuryVotes AS vote
            INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = vote.PlayAwardCategoryId
            WHERE vote.JuryId = @jury AND candidate.PlayId = @play AND vote.IsActive = 1 AND vote.IsPublished = 1
            """, ("@jury", fixture.JuryId), ("@play", fixture.PlayId)) == 3,
            "Concurrent first submissions commit every required default/director/actress card exactly once.");
        var before = await MutationSnapshotAsync(fixture);
        Check(await SaveAsync(fixture, fee == 111 ? 222 : 111, 9) == JuryVotingSaveVoteResult.TicketFeeAlreadySaved,
            "Retry cannot replace the winning first fee.");
        Check(await MutationSnapshotAsync(fixture) == before, "Rejected retry preserves all successful first-submission data.");
        Console.WriteLine("PASS: simultaneous first submissions keep a single immutable fee and atomic votes.");
    }

    private async Task TestAdminCorrectionAsync(Fixture fixture)
    {
        await using var context = Context();
        var adminId = Guid.NewGuid();
        await ExecuteAsync("""
            INSERT INTO dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
            VALUES (@id, N'Regression', N'Admin', @username, N'not-a-real-hash', @email, 1, 1, 1, 0)
            """, ("@id", adminId), ("@username", "admin." + adminId.ToString("N")[..12]), ("@email", adminId + "@example.invalid"));
        var controller = new ManagementController(context, null!, null!, null!, null!, null!, null!, null!, null!,
            null!, null!, null!, null!, null!, NullLogger<ManagementController>.Instance);
        var http = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, adminId.ToString()), new Claim(ClaimTypes.Role, "Admin")], "Regression"))
        };
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        controller.TempData = new TempDataDictionary(http, new MemoryTempDataProvider());
        var feeId = await FeeIdAsync(fixture);
        var result = await controller.UpdateTicketFee(feeId, new EditTicketFeeViewModel { Id = feeId, TicketFee = 300 }, default);
        Check(result is RedirectToActionResult && await NumberAsync("SELECT CONVERT(int, TicketFee) FROM dbo.JuryGameTicketFees WHERE Id = @id", ("@id", feeId)) == 300,
            "Authorized admin correction still works; jury lock does not make SQL/admin fee corrections immutable.");
        Check(await SaveAsync(fixture, 123, 6) == JuryVotingSaveVoteResult.TicketFeeAlreadySaved,
            "Jury cannot undo an authorized administrator correction.");
        Check(await SaveAsync(fixture, null, 6) == JuryVotingSaveVoteResult.Success,
            "After admin correction jury can continue vote edits without changing the corrected fee.");
        Console.WriteLine("PASS: authorized administrator fee correction remains supported.");
    }

    private async Task TestRollbackAsync(Fixture fixture)
    {
        await using var context = Context();
        var migrations = context.Database.GetMigrations().ToArray();
        var current = migrations.Single(id => id.Contains("_UnlimitedAdditionalVotingUpdates_v_", StringComparison.Ordinal));
        var predecessor = migrations[Array.IndexOf(migrations, current) - 1];
        var before = await MutationSnapshotAsync(fixture);
        var allUsageCount = await NumberAsync("SELECT COUNT(*) FROM dbo.AdditionalVotingUsages");
        var migrator = context.GetService<IMigrator>();
        await migrator.MigrateAsync(predecessor);
        Check(await MutationSnapshotAsync(fixture) == before && await NumberAsync("SELECT COUNT(*) FROM dbo.AdditionalVotingUsages") == allUsageCount,
            "Rollback preserves repeated usage history, votes and saved fees.");
        Check(await NumberAsync("SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages') AND name = N'UX_AdditionalVotingUsages_OneTime' AND is_unique = 0") == 1,
            "Safe rollback keeps old-name historical index nonunique rather than deleting colliding events.");
        await migrator.MigrateAsync();
        Check(await MutationSnapshotAsync(fixture) == before && await NumberAsync("SELECT COUNT(*) FROM dbo.AdditionalVotingUsages") == allUsageCount,
            "Reapply preserves repeated usage history, votes and saved fees.");
        Check(await SaveAsync(fixture, null, 7) == JuryVotingSaveVoteResult.Success,
            "Reapplied migration permits further updates despite retained repeated event history.");
        Console.WriteLine("PASS: rollback/reapply preserves unlimited history without duplicate key failures.");
    }

    private async Task<Fixture> SeedFixtureAsync()
    {
        var juryId = Guid.NewGuid();
        var formId = Guid.NewGuid();
        await ExecuteAsync("""
            INSERT INTO dbo.Users
            (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
            VALUES (@jury, N'Regression', N'Jury', @username, N'not-a-real-hash', @email, 1, 2, 1, 0);
            INSERT INTO dbo.Form
            (Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName, TheatreName,
             PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email, Director,
             LeadActress, IsActive, IsPublished)
            VALUES (@form, @application, SYSDATETIME(), SYSDATETIME(), @name,
             N'Regression Theater', '2026-08-01', N'[]', N'Regression Applicant',
             N'Producer', N'5551234567', @email, N'Regression Director',
             N'[{"Name":"Regression Candidate","Role":"Lead"}]', 1, 1)
            """, ("@jury", juryId), ("@form", formId), ("@application", formId.ToString("N")[..6]),
            ("@username", "jury." + juryId.ToString("N")[..12]), ("@email", juryId + "@example.invalid"),
            ("@name", "Regression " + formId.ToString("N")[..10]));
        await using var context = Context();
        var playId = await context.Plays.AsNoTracking().Where(play => play.SourceFormId == formId)
            .Select(play => play.Id).SingleAsync();
        // Form publication intentionally starts with jury visibility off.
        // The admin enables the play before juries can vote.
        await ExecuteAsync("UPDATE dbo.Plays SET JuriOylamaStatus = 1 WHERE Id = @play", ("@play", playId));
        var candidates = await context.PlayAwardCategories.AsNoTracking().Where(candidate =>
                candidate.PlayId == playId && candidate.IsActive && candidate.IsCurrent)
            .OrderBy(candidate => candidate.AwardCategoryCode).ToArrayAsync();
        Check(candidates.Select(candidate => candidate.AwardCategoryCode).SequenceEqual(new[] { 1001, 1002, 1003 }),
            "Real Form synchronization creates a valid voting play with default, director and actress cards.");
        return new Fixture(juryId, playId, candidates.Single(candidate => candidate.AwardCategoryCode == 1003).Id,
            candidates.Select(candidate => candidate.Id).ToArray());
    }

    private async Task ResetPermissionAsync() => await ExecuteAsync("""
        UPDATE dbo.AdditionalVotings SET StartDate = @start, EndDate = @end, IsActive = 1,
            IsPublished = 1, AppliesToAllJuries = 1, AppliesToAllPlays = 1 WHERE Id = @id
        """, ("@id", permissionId), ("@start", Today.AddDays(-1).ToDateTime(TimeOnly.MinValue)),
        ("@end", Today.AddDays(1).ToDateTime(TimeOnly.MinValue)));

    private async Task<JuryVotingSaveVoteResult> SaveAsync(Fixture fixture, int? fee, int score, Guid? explicitFeeId = null)
    {
        await using var context = Context();
        var voteIds = await context.JuryVotes.AsNoTracking().Where(vote => vote.JuryId == fixture.JuryId &&
            fixture.CandidateIds.Contains(vote.PlayAwardCategoryId)).ToDictionaryAsync(vote => vote.PlayAwardCategoryId, vote => vote.Id);
        var feeId = explicitFeeId ?? await context.JuryGameTicketFees.IgnoreQueryFilters().AsNoTracking().Where(ticket =>
            ticket.UserId == fixture.JuryId && ticket.PlayId == fixture.PlayId).Select(ticket => (Guid?)ticket.Id).SingleOrDefaultAsync();
        return await Service(context).SaveVoteAsync(fixture.JuryId, Request(fixture, fee, score, feeId, voteIds));
    }

    private static SaveVoteRequest Request(Fixture fixture, int? fee, int score, Guid? feeId, IReadOnlyDictionary<Guid, Guid>? voteIds) => new()
    {
        PlayId = fixture.PlayId, TicketFee = fee, TicketFeeId = feeId,
        // Every logical card is mandatory. Only the actress score changes;
        // default-play and director scores retain their first-vote value.
        Scores = fixture.CandidateIds.Select(id => new CategoryVoteRequest
        {
            PlayAwardCategoryId = id,
            JuryVoteId = voteIds is not null && voteIds.TryGetValue(id, out var voteId) ? voteId : null,
            Score = id == fixture.CandidateId ? score : 5
        }).ToList(),
        OperationContext = new JuryOperationContext { CorrelationId = Guid.NewGuid() }
    };

    private static JuryVotingService Service(AfifeContext context) => new(new VotingContextBridge(context), NullLogger<JuryVotingService>.Instance);
    private async Task<JuryVotingPlayDetailViewModel> DetailAsync(Fixture fixture)
    {
        await using var context = Context();
        var slug = await context.Plays.Where(play => play.Id == fixture.PlayId).Select(play => play.Slug).SingleAsync();
        return await Service(context).BuildPlayDetailPageModelAsync(fixture.JuryId, slug);
    }
    private async Task<Guid> FeeIdAsync(Fixture fixture)
    {
        await using var context = Context();
        return await context.JuryGameTicketFees.IgnoreQueryFilters().Where(fee => fee.UserId == fixture.JuryId &&
            fee.PlayId == fixture.PlayId).Select(fee => fee.Id).SingleAsync();
    }
    private async Task<int> UsageCountAsync(Fixture fixture) => await NumberAsync(
        "SELECT COUNT(*) FROM dbo.AdditionalVotingUsages WHERE JuryId = @jury AND PlayId = @play AND IsPublished = 1",
        ("@jury", fixture.JuryId), ("@play", fixture.PlayId));
    private async Task<string> TicketSnapshotAsync(Fixture fixture)
    {
        await using var context = Context();
        var rows = await context.JuryGameTicketFees.IgnoreQueryFilters().AsNoTracking()
            .Where(fee => fee.UserId == fixture.JuryId && fee.PlayId == fixture.PlayId).OrderBy(fee => fee.Id)
            .Select(fee => new { fee.Id, fee.TicketFee, fee.IsPublished, fee.CreatedAt, fee.CreatedBy, fee.UpdatedAt, fee.UpdatedBy }).ToArrayAsync();
        return JsonSerializer.Serialize(rows);
    }
    private async Task<string> MutationSnapshotAsync(Fixture fixture)
    {
        await using var context = Context();
        var votes = await context.JuryVotes.IgnoreQueryFilters().AsNoTracking().Where(vote => vote.JuryId == fixture.JuryId &&
                fixture.CandidateIds.Contains(vote.PlayAwardCategoryId)).OrderBy(vote => vote.Id)
            .Select(vote => new { vote.Id, vote.Score, vote.IsActive, vote.IsPublished, vote.UpdatedAt, vote.UpdatedBy }).ToArrayAsync();
        var usages = await context.AdditionalVotingUsages.IgnoreQueryFilters().AsNoTracking().Where(usage =>
                usage.JuryId == fixture.JuryId && usage.PlayId == fixture.PlayId).OrderBy(usage => usage.Id)
            .Select(usage => new { usage.Id, usage.AdditionalVotingId, usage.UsageType, usage.IsActive, usage.IsPublished, usage.UsedAt }).ToArrayAsync();
        return JsonSerializer.Serialize(new { votes, usages, fee = await TicketSnapshotAsync(fixture) });
    }
    private async Task ExecuteAsync(string sql, params (string Name, object Value)[] values)
    {
        await using var sqlConnection = new SqlConnection(connection);
        await sqlConnection.OpenAsync();
        await using var command = new SqlCommand(sql, sqlConnection) { CommandTimeout = 120 };
        foreach (var (name, value) in values) command.Parameters.AddWithValue(name, value);
        await command.ExecuteNonQueryAsync();
    }
    private async Task<int> NumberAsync(string sql, params (string Name, object Value)[] values)
    {
        await using var sqlConnection = new SqlConnection(connection);
        await sqlConnection.OpenAsync();
        await using var command = new SqlCommand(sql, sqlConnection) { CommandTimeout = 120 };
        foreach (var (name, value) in values) command.Parameters.AddWithValue(name, value);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }
    private static bool DifferentScores(string? oldJson, string? newJson)
    {
        if (oldJson is null || newJson is null) return false;
        using var oldDocument = JsonDocument.Parse(oldJson);
        using var newDocument = JsonDocument.Parse(newJson);
        var oldScores = oldDocument.RootElement.EnumerateArray().ToDictionary(
            row => row.GetProperty("playAwardCategoryId").GetGuid(), row => row.GetProperty("score").GetInt32());
        return newDocument.RootElement.EnumerateArray().Any(row =>
            oldScores.TryGetValue(row.GetProperty("playAwardCategoryId").GetGuid(), out var oldScore) &&
            oldScore != row.GetProperty("score").GetInt32());
    }
    private void Check(bool condition, string message)
    {
        assertions++;
        if (!condition) throw new InvalidOperationException("FAIL: " + message);
    }
    private sealed record Fixture(Guid JuryId, Guid PlayId, Guid CandidateId, Guid[] CandidateIds);
    private sealed class MemoryTempDataProvider : ITempDataProvider
    {
        public IDictionary<string, object> LoadTempData(HttpContext context) => new Dictionary<string, object>();
        public void SaveTempData(HttpContext context, IDictionary<string, object> values) { }
    }
}
