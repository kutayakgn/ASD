using System.Data.Common;
using System.Reflection;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using YKBAfife.Controllers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Services.Audit;

var connectionIndex = Array.IndexOf(args, "--connection");
if (connectionIndex < 0 || connectionIndex + 1 >= args.Length) throw new ArgumentException("--connection is required.");
var connectionString = args[connectionIndex + 1];
var connection = new SqlConnectionStringBuilder(connectionString);
if (!Regex.IsMatch(connection.DataSource, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase) ||
    !Regex.IsMatch(connection.InitialCatalog, "^YkbAfifeBulkVotesTest_[a-f0-9]{32}$"))
    throw new InvalidOperationException("Bulk reset tests require a validated disposable LocalDB database.");

var accessor = new HttpContextAccessor();
var commands = new VoteCommandCounter();
var options = new DbContextOptionsBuilder<AfifeContext>().UseSqlServer(connectionString)
    .AddInterceptors(new AdminAuditConnectionInterceptor(accessor), commands).Options;
await using (var migrationContext = new AfifeContext(options)) await migrationContext.Database.MigrateAsync();

var actor = Guid.NewGuid();
var jury = Guid.NewGuid();
var otherJury = Guid.NewGuid();
var play = Guid.NewGuid();
var otherPlay = Guid.NewGuid();
var candidate = Guid.NewGuid();
var currentHistoricalSlot = Guid.NewGuid();
var historicalCandidate = Guid.NewGuid();
var inactiveCandidate = Guid.NewGuid();
var unselectedCandidate = Guid.NewGuid();
var foreignCandidate = Guid.NewGuid();
var hiddenHistoryCandidate = Guid.NewGuid();
var before = TurkeyTime.Now;
var suffix = Guid.NewGuid().ToString("N");
var assertions = 0;

void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    assertions++;
}

async Task<T?> ScalarAsync<T>(string sql, params (string Name, object Value)[] values)
{
    await using var sqlConnection = new SqlConnection(connectionString);
    await sqlConnection.OpenAsync();
    await using var command = sqlConnection.CreateCommand();
    command.CommandText = sql;
    foreach (var value in values) command.Parameters.AddWithValue(value.Name, value.Value);
    var result = await command.ExecuteScalarAsync();
    return result is null or DBNull ? default : (T)result;
}

Task<string?> SnapshotAsync() => ScalarAsync<string>("""
    SELECT CONCAT(
        (SELECT * FROM dbo.JuryVotes WHERE JuryId IN (@jury, @otherJury) ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
        N'|', (SELECT * FROM dbo.Rankings WHERE PlayId IN (@play, @otherPlay) ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES));
    """, ("@jury", jury), ("@otherJury", otherJury), ("@play", play), ("@otherPlay", otherPlay));

async Task<(IActionResult Result, Guid Correlation)> ResetAsync(Guid requestedPlay, Guid requestedJury, string? ids,
    bool authenticated = true, bool invalidModel = false)
{
    var correlation = Guid.NewGuid();
    var http = new DefaultHttpContext { TraceIdentifier = correlation.ToString() };
    http.Request.Method = "POST";
    http.Request.Path = "/oylama-gecmisi/tum-oylamalari-sifirla";
    http.Request.RouteValues["controller"] = "Management";
    http.Request.RouteValues["action"] = nameof(ManagementController.ResetJuryVotes);
    http.User = new ClaimsPrincipal(new ClaimsIdentity(authenticated
        ? [new Claim(ClaimTypes.NameIdentifier, actor.ToString()), new Claim(ClaimTypes.Role, "Admin")]
        : [], authenticated ? "Regression" : null));
    accessor.HttpContext = http;
    await using var context = new AfifeContext(options);
    var constructor = typeof(ManagementController).GetConstructors().Single();
    var parameters = constructor.GetParameters().Select(parameter => parameter.ParameterType == typeof(AfifeContext)
        ? (object)context : parameter.ParameterType == typeof(Microsoft.Extensions.Logging.ILogger<ManagementController>)
            ? NullLogger<ManagementController>.Instance : null).ToArray();
    var controller = (ManagementController)constructor.Invoke(parameters);
    controller.ControllerContext = new ControllerContext { HttpContext = http };
    if (invalidModel) controller.ModelState.AddModelError("playId", "Invalid ID.");
    commands.Reset();
    var result = await controller.ResetJuryVotes(requestedPlay, requestedJury, ids, default);
    return (result, correlation);
}

await using (var seed = new AfifeContext(options))
{
    await seed.Database.ExecuteSqlInterpolatedAsync($"""
        INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
        VALUES ({actor}, N'Bulk', N'Actor', {"actor" + suffix[..18]}, N'fixture-not-a-password', {"actor" + suffix + "@example.invalid"}, 1, 1, 1, 0),
               ({jury}, N'Bulk', N'Jury', {"jury" + suffix[..18]}, N'fixture-not-a-password', {"jury" + suffix + "@example.invalid"}, 1, 2, 0, 0),
               ({otherJury}, N'Other', N'Jury', {"other" + suffix[..18]}, N'fixture-not-a-password', {"other" + suffix + "@example.invalid"}, 1, 2, 1, 0);
        INSERT dbo.Plays (Id, PlayName, TheaterName, Slug, StatusCode, CreatedAt, IsPublished, IsActive, JuriOylamaStatus, KunyeGirisStatus, RecordType)
        VALUES ({play}, N'Bulk vote play', N'Bulk theatre', {"bulk-" + suffix}, 1, {before}, 1, 1, 1, 0, 0),
               ({otherPlay}, N'Foreign bulk play', N'Other theatre', {"foreign-" + suffix}, 1, {before}, 1, 1, 1, 0, 0);
        INSERT dbo.PlayAwardCategories (Id, PlayId, CreatedAt, IsPublished, IsActive, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
        VALUES ({candidate}, {play}, {before}, 1, 1, N'Bulk candidate', 1003, 1, N'Lead', 2),
               ({currentHistoricalSlot}, {play}, {before}, 1, 1, N'Current candidate', 1003, 1, N'Lead', 1),
               ({historicalCandidate}, {play}, {before}, 1, 1, N'Historical candidate', 1003, 0, N'Lead', 1),
               ({inactiveCandidate}, {play}, {before}, 1, 0, N'Inactive candidate', 1004, 1, N'Lead', 3),
               ({unselectedCandidate}, {play}, {before}, 1, 1, N'Unselected candidate', 1007, 1, N'Design', 4),
               ({foreignCandidate}, {otherPlay}, {before}, 1, 1, N'Foreign candidate', 1003, 1, N'Lead', 1),
               ({hiddenHistoryCandidate}, {play}, {before}, 1, 1, N'Already reset candidate', 1009, 1, N'Music', 5);
        INSERT dbo.JuryVotes (Id, PlayAwardCategoryId, CreatedAt, IsPublished, IsActive, Score, JuryId)
        VALUES (NEWID(), {candidate}, {before}, 1, 1, 8, {jury}),
               (NEWID(), {candidate}, {before}, 1, 1, 5, {otherJury}),
               (NEWID(), {historicalCandidate}, {before}, 1, 0, 7, {jury}),
               (NEWID(), {inactiveCandidate}, {before}, 1, 0, 6, {jury}),
               (NEWID(), {unselectedCandidate}, {before}, 1, 1, 9, {jury}),
               (NEWID(), {foreignCandidate}, {before}, 1, 1, 4, {jury}),
               (NEWID(), {hiddenHistoryCandidate}, {before}, 0, 0, 3, {jury});
        """);
}

var method = typeof(ManagementController).GetMethod(nameof(ManagementController.ResetJuryVotes))!;
Check(method.IsDefined(typeof(ValidateAntiForgeryTokenAttribute)), "Bulk reset must retain antiforgery.");
Check(method.IsDefined(typeof(AdminMutationAuditAttribute)), "Bulk reset must retain admin mutation audit.");
Check(method.GetCustomAttribute<HttpPostAttribute>()?.Template == "oylama-gecmisi/tum-oylamalari-sifirla", "Bulk route must be POST-only.");
var initial = await SnapshotAsync();
var unauthorized = await ResetAsync(play, jury, JsonSerializer.Serialize(new[] { candidate }), authenticated: false);
Check(unauthorized.Result is UnauthorizedObjectResult && commands.VoteUpdates == 0, "Invalid actor must be rejected before SQL mutation.");

foreach (var invalid in new string?[] { null, "", "null", "{}", "not json", "[]", "[null]", "[\"invalid-guid\"]", JsonSerializer.Serialize(new[] { Guid.Empty }) })
{
    var rejected = await ResetAsync(play, jury, invalid);
    Check(rejected.Result is BadRequestObjectResult && commands.VoteUpdates == 0, "Malformed/empty ID scope must not execute an UPDATE.");
}
var invalidModel = await ResetAsync(play, jury, JsonSerializer.Serialize(new[] { candidate }), invalidModel: true);
Check(invalidModel.Result is BadRequestObjectResult && commands.VoteUpdates == 0, "Invalid model must be rejected before mutation.");

var mismatches = new[]
{
    new[] { candidate, foreignCandidate }, new[] { candidate, hiddenHistoryCandidate }, new[] { candidate, Guid.NewGuid() },
    Enumerable.Range(0, 1100).Select(_ => Guid.NewGuid()).Append(candidate).ToArray()
};
foreach (var mismatch in mismatches)
{
    var rejected = await ResetAsync(play, jury, JsonSerializer.Serialize(mismatch));
    Check(rejected.Result is BadRequestObjectResult && commands.VoteUpdates == 1, "Mismatched scope must execute one atomic UPDATE and reject.");
    Check(await SnapshotAsync() == initial, "Mismatched scope must roll back votes and derived rankings.");
    Check(await ScalarAsync<int>("SELECT COUNT(*) FROM dbo.AdminLogs WHERE CorrelationId = @id", ("@id", rejected.Correlation)) == 0,
        "Rolled-back reset must not leave successful SQL audit rows.");
}
foreach (var wrongScope in new[] { (otherPlay, jury), (play, Guid.NewGuid()), (Guid.Empty, jury), (play, Guid.Empty) })
{
    var rejected = await ResetAsync(wrongScope.Item1, wrongScope.Item2, JsonSerializer.Serialize(new[] { candidate }));
    Check(rejected.Result is BadRequestObjectResult && await SnapshotAsync() == initial, "Wrong jury/play scope must preserve all votes.");
}

var resetStarted = TurkeyTime.Now;
var success = await ResetAsync(play, jury, " \n" + JsonSerializer.Serialize(new[] { candidate, historicalCandidate, inactiveCandidate }) + " \n");
Check(success.Result is JsonResult && commands.VoteUpdates == 1, "Bulk reset must succeed using exactly one SQL UPDATE.");
var payload = JsonSerializer.SerializeToElement(((JsonResult)success.Result).Value);
Check(payload.GetProperty("success").GetBoolean() && payload.GetProperty("resetCount").GetInt32() == 3, "Affected row count must equal the distinct rendered scope.");
await using (var check = new AfifeContext(options))
{
    var resetVotes = await check.JuryVotes.IgnoreQueryFilters().AsNoTracking()
        .Where(vote => vote.JuryId == jury && new[] { candidate, historicalCandidate, inactiveCandidate }.Contains(vote.PlayAwardCategoryId)).ToArrayAsync();
    Check(resetVotes.Length == 3 && resetVotes.All(vote => !vote.IsPublished && vote.UpdatedBy == actor && vote.UpdatedAt >= resetStarted && vote.UpdatedAt <= TurkeyTime.Now),
        "Every reset vote must record the same actor/time and publication change.");
    Check(resetVotes.Single(vote => vote.PlayAwardCategoryId == candidate).IsActive &&
          !resetVotes.Single(vote => vote.PlayAwardCategoryId == historicalCandidate).IsActive &&
          !resetVotes.Single(vote => vote.PlayAwardCategoryId == inactiveCandidate).IsActive,
        "Bulk reset must preserve the single-reset IsActive behavior.");
    Check(await check.JuryVotes.AsNoTracking().AnyAsync(vote => vote.JuryId == otherJury && vote.PlayAwardCategoryId == candidate), "Other jury vote must remain published.");
    Check(await check.JuryVotes.AsNoTracking().AnyAsync(vote => vote.JuryId == jury && vote.PlayAwardCategoryId == foreignCandidate), "Other play vote must remain published.");
    Check(await check.JuryVotes.AsNoTracking().AnyAsync(vote => vote.JuryId == jury && vote.PlayAwardCategoryId == unselectedCandidate), "Unposted candidate must remain published.");
    Check(await check.Rankings.AsNoTracking().AnyAsync(row => row.PlayAwardCategoryId == candidate && row.NumberOfActiveVote == 1 && row.ArithmeticMean == 5),
        "Set-based reset must refresh the affected ranking.");
    var audit = await check.AdminLogs.AsNoTracking().Where(row => row.CorrelationId == success.Correlation && row.TableName == "JuryVotes").ToArrayAsync();
    Check(audit.Length == 1 && audit[0].AffectedRowCount == 3 && audit[0].UserId == actor && audit[0].ActionName == nameof(ManagementController.ResetJuryVotes),
        "Bulk UPDATE must produce one consolidated vote audit with actor/action/correlation.");
}
var duplicate = await ResetAsync(play, jury, JsonSerializer.Serialize(new[] { unselectedCandidate, unselectedCandidate }));
Check(duplicate.Result is JsonResult && commands.VoteUpdates == 1 &&
    JsonSerializer.SerializeToElement(((JsonResult)duplicate.Result).Value).GetProperty("resetCount").GetInt32() == 1,
    "Duplicate candidate IDs must reset once.");
Console.WriteLine($"PASS: {assertions} bulk vote reset assertions (atomic SQL update, >1024 IDs, audit, ranking and eligibility compatibility).");

sealed class VoteCommandCounter : DbCommandInterceptor
{
    public int VoteUpdates { get; private set; }
    public void Reset() => VoteUpdates = 0;
    public override ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(DbCommand command, CommandEventData eventData,
        InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        if (command.CommandText.TrimStart().StartsWith("UPDATE", StringComparison.OrdinalIgnoreCase) && command.CommandText.Contains("[JuryVotes]")) VoteUpdates++;
        return base.NonQueryExecutingAsync(command, eventData, result, cancellationToken);
    }
}
