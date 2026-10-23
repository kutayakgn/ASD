using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Models.Entities;
using YKBAfife.Services.Authentication;

var arguments = Enumerable.Range(0, args.Length / 2)
    .ToDictionary(index => args[index * 2], index => args[index * 2 + 1], StringComparer.Ordinal);
if (args.Length != 6 || !arguments.TryGetValue("--connection", out var connectionString) ||
    !arguments.TryGetValue("--root", out var repositoryRoot) ||
    !arguments.TryGetValue("--configuration", out var configuration) || configuration is not ("Debug" or "Release"))
    throw new ArgumentException("Use the dedicated disposable admin workflow runner.");
var settings = new SqlConnectionStringBuilder(connectionString);
if (!Regex.IsMatch(settings.DataSource, @"^\(localdb\)\\[A-Za-z0-9_-]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant) ||
    !Regex.IsMatch(settings.InitialCatalog, "^YkbAfifeAdminWorkflowTest_[a-f0-9]{32}$") || !settings.IntegratedSecurity)
    throw new ArgumentException("Only the dedicated GUID-suffixed LocalDB workflow database is allowed.");
repositoryRoot = Path.GetFullPath(repositoryRoot);
var applicationDirectory = Path.Combine(repositoryRoot, "src", "YKBAfife");
var applicationDll = Path.Combine(applicationDirectory, "bin", configuration, "net8.0", "YKBAfife.dll");
if (!File.Exists(applicationDll)) throw new InvalidOperationException("Build the application before running HTTP workflows.");
var logDirectory = Path.Combine(repositoryRoot, "artifacts", "diagnostics");
Directory.CreateDirectory(logDirectory);
var logPath = Path.Combine(logDirectory, "admin-workflows-" + Guid.NewGuid().ToString("N") + ".log");

var options = new DbContextOptionsBuilder<AfifeContext>()
    .UseSqlServer(connectionString, sql => sql.CommandTimeout(180))
    .ReplaceService<IMigrationsSqlGenerator, NoDataLossSqlServerMigrationsSqlGenerator>().Options;
await using var context = new AfifeContext(options);
await context.Database.MigrateAsync();

const string oldPassword = "WorkflowOld42<>&lt;onx=";
const string newPassword = "WorkflowNew43<>";
var loginId = Guid.NewGuid();
var adminId = Guid.NewGuid();
var juryId = Guid.NewGuid();
var otherId = Guid.NewGuid();
var modernSalt = RandomNumberGenerator.GetBytes(16);
var modernHash = Rfc2898DeriveBytes.Pbkdf2(oldPassword, modernSalt, 600_000, HashAlgorithmName.SHA256, 32);
var modernPassword = "pbkdf2-sha256$600000$" + Convert.ToBase64String(modernSalt) + "$" + Convert.ToBase64String(modernHash);
var rows = new[]
{
    Fixture(loginId, "workflow.operator", "Workflow Operator", 1, PasswordHashHelper.HashPassword(oldPassword)),
    Fixture(adminId, "workflow.admin", "Workflow Admin", 1, modernPassword),
    Fixture(juryId, "workflow.jury", "Workflow Jury", 2, PasswordHashHelper.HashPassword(oldPassword)),
    Fixture(otherId, "workflow.other", "Workflow Other", 2, "opaque-existing-unsupported-hash")
};
context.Users.AddRange(rows);
await context.SaveChangesAsync();
var baselineHashes = await Hashes();

var listener = new TcpListener(IPAddress.Loopback, 0);
listener.Start();
var port = ((IPEndPoint)listener.LocalEndpoint).Port;
listener.Stop();
var baseAddress = new Uri($"http://127.0.0.1:{port}/");
var start = new ProcessStartInfo("dotnet")
{
    WorkingDirectory = applicationDirectory,
    UseShellExecute = false,
    CreateNoWindow = true,
    RedirectStandardOutput = true,
    RedirectStandardError = true
};
start.ArgumentList.Add(applicationDll);
start.Environment["ConnectionStrings__AfifeConnectionString"] = connectionString;
start.Environment["ASPNETCORE_ENVIRONMENT"] = "Development";
start.Environment["DOTNET_ENVIRONMENT"] = "Development";
start.Environment["ASPNETCORE_URLS"] = baseAddress.ToString().TrimEnd('/');
start.Environment.Remove("ASPNETCORE_HTTPS_PORT");
start.Environment.Remove("ASPNETCORE_HTTPS_PORTS");
start.Environment["Logging__LogLevel__Default"] = "Warning";
start.Environment["Logging__LogLevel__Microsoft.AspNetCore"] = "Warning";
start.Environment["Logging__LogLevel__Microsoft.EntityFrameworkCore.Database.Command"] = "Warning";
using var log = new StreamWriter(logPath, false, Encoding.UTF8) { AutoFlush = true };
var logLock = new object();
var assertions = 0;
Process? app = null;
string? alternateContentRoot = null;
try
{
    StartApplication();
    var cookies = new CookieContainer();
    using var handler = new HttpClientHandler { CookieContainer = cookies, AllowAutoRedirect = true };
    using var client = new HttpClient(handler) { BaseAddress = baseAddress, Timeout = TimeSpan.FromSeconds(15) };
    await WaitForStartup(client);

    var loginPage = await Get(client, "giris-yap");
    using var loginHandler = new HttpClientHandler { CookieContainer = cookies, AllowAutoRedirect = false };
    using var loginClient = new HttpClient(loginHandler) { BaseAddress = baseAddress };
    var loginStarted = DateTimeOffset.UtcNow;
    using var loginResponse = await loginClient.PostAsync("giris-yap", new FormUrlEncodedContent(new Dictionary<string, string>
    {
        ["__RequestVerificationToken"] = Antiforgery(loginPage),
        ["Username"] = "workflow.operator", ["Password"] = oldPassword
    }));
    Check(loginResponse.StatusCode == HttpStatusCode.Found && loginResponse.Headers.Location is not null &&
          !loginResponse.Headers.Location.ToString().Contains("/giris-yap", StringComparison.Ordinal),
        "Actual HTTP login accepts exact existing credential punctuation through the global filter.");
    var loginHtml = await Get(client, loginResponse.Headers.Location!.ToString());
    Check(!loginHtml.Contains(oldPassword, StringComparison.Ordinal), "Login response never exposes the credential.");
    Check((await Hashes()).OrderBy(pair => pair.Key).SequenceEqual(baselineHashes.OrderBy(pair => pair.Key)),
        "HTTP login does not rehash existing credentials.");

    await TestSessions(client, cookies, loginResponse, loginStarted, loginHtml);

    foreach (var target in new[]
    {
        new Target(adminId, "workflow.admin", "admin-yonetimi", false),
        new Target(juryId, "workflow.jury", "juriler", true)
    })
    {
        var path = $"{target.Route}/{target.Id}/duzenle";
        var html = await Get(client, path);
        AssertPasswordUi(html, baselineHashes[target.Id]);

        var oldHash = (await Hashes())[target.Id];
        var firstName = target.IsJury ? "Workflow Jury Updated" : "Workflow Admin Updated";
        html = await Save(client, path, target, html, firstName, "");
        AssertPasswordUi(html, oldHash);
        var afterBlank = await Hashes();
        Check(afterBlank[target.Id] == oldHash && PasswordHashHelper.VerifyPassword(oldPassword, afterBlank[target.Id]),
            "Full-name-only edit keeps the existing credential byte-exact and usable.");
        Check(await FullName(target.Id) == firstName, "The blank-password form actually saved the requested profile edit.");
        Check(afterBlank.OrderBy(pair => pair.Key).SequenceEqual(baselineHashes.OrderBy(pair => pair.Key)),
            "Profile-only edit changes no user's credential.");

        html = await Save(client, path, target, html, "SingleName", newPassword);
        AssertPasswordUi(html, oldHash);
        Check((await Hashes())[target.Id] == oldHash && await FullName(target.Id) == firstName,
            "Validation failure leaves the existing profile and hash unchanged.");
        Check(!html.Contains(newPassword, StringComparison.Ordinal) &&
              !html.Contains(WebUtility.HtmlEncode(newPassword), StringComparison.Ordinal),
            "Validation failure never reflects the submitted password into HTML.");

        var beforeReplacement = await Hashes();
        html = await Save(client, path, target, html, firstName + " Again", newPassword);
        var afterReplacement = await Hashes();
        AssertPasswordUi(html, afterReplacement[target.Id]);
        Check(afterReplacement[target.Id] != oldHash &&
              PasswordHashHelper.VerifyPassword(newPassword, afterReplacement[target.Id]) &&
              !PasswordHashHelper.VerifyPassword(oldPassword, afterReplacement[target.Id]),
            "An explicit new credential replaces the target hash and verifies only the new password.");
        Check(beforeReplacement.Where(pair => pair.Key != target.Id).OrderBy(pair => pair.Key)
                .SequenceEqual(afterReplacement.Where(pair => pair.Key != target.Id).OrderBy(pair => pair.Key)),
            "Explicit password edit changes only the selected user's hash.");
        // Later target checks compare with the cumulative expected credentials.
        baselineHashes = afterReplacement;
    }

    Check((await Hashes())[otherId] == "opaque-existing-unsupported-hash", "Unrecognized historical hashes remain untouched.");
    await TestBulkReset(client);
    Console.WriteLine($"PASS: {assertions} actual HTTP credential, voting-history and session assertions; local process and database are disposable.");
}
catch
{
    Console.Error.WriteLine($"Workflow application diagnostics: {logPath}");
    throw;
}
finally
{
    await StopApplication();
    if (alternateContentRoot is not null && Directory.Exists(alternateContentRoot))
    {
        // This fixture creates an empty directory only; never recursively
        // remove a directory to clean up a test process's unexpected output.
        Directory.Delete(alternateContentRoot, recursive: false);
    }
}

void StartApplication()
{
    var candidate = new Process { StartInfo = start };
    candidate.OutputDataReceived += (_, item) => { if (item.Data is not null) lock (logLock) log.WriteLine(item.Data); };
    candidate.ErrorDataReceived += (_, item) => { if (item.Data is not null) lock (logLock) log.WriteLine(item.Data); };
    try
    {
        if (!candidate.Start()) throw new InvalidOperationException("Could not start the disposable workflow application.");
    }
    catch
    {
        candidate.Dispose();
        throw;
    }
    app = candidate;
    app.BeginOutputReadLine();
    app.BeginErrorReadLine();
}
async Task StopApplication()
{
    if (app is null) return;
    if (!app.HasExited)
    {
        app.Kill(entireProcessTree: true);
        await app.WaitForExitAsync();
    }
    app.Dispose();
    app = null;
}

User Fixture(Guid id, string username, string fullName, int role, string hash)
{
    var pieces = fullName.Split(' ');
    return new User
    {
        Id = id, Username = username, FirstName = pieces[0], LastName = pieces[1],
        Email = username + "@example.invalid", Phone = "5550000000", PasswordHash = hash,
        RoleCode = role, CreatedAt = DateTime.UtcNow, IsPublished = true, IsActive = true
    };
}
void Check(bool condition, string description)
{
    if (!condition) throw new InvalidOperationException(description);
    assertions++;
}
async Task<Dictionary<Guid, string>> Hashes() => await context.Users.IgnoreQueryFilters().AsNoTracking()
    .ToDictionaryAsync(user => user.Id, user => user.PasswordHash);
async Task<string> FullName(Guid id) => await context.Users.AsNoTracking().Where(user => user.Id == id)
    .Select(user => user.FirstName + " " + user.LastName).SingleAsync();
async Task WaitForStartup(HttpClient client)
{
    var deadline = Stopwatch.StartNew();
    while (deadline.Elapsed < TimeSpan.FromSeconds(60))
    {
        if (app is null || app.HasExited) throw new InvalidOperationException("Workflow application exited before HTTP startup.");
        try
        {
            using var response = await client.GetAsync("giris-yap");
            if (response.IsSuccessStatusCode) return;
        }
        catch (HttpRequestException) { }
        await Task.Delay(200);
    }
    throw new TimeoutException("Workflow application did not start on the selected loopback port.");
}
async Task<string> Get(HttpClient client, string path)
{
    using var response = await client.GetAsync(path);
    Check(response.IsSuccessStatusCode, "Workflow page returns a successful HTTP response.");
    return await response.Content.ReadAsStringAsync();
}
async Task<string> Save(HttpClient client, string path, Target target, string html, string fullName, string password)
{
    var fields = new Dictionary<string, string>
    {
        ["__RequestVerificationToken"] = Antiforgery(html), ["Id"] = target.Id.ToString(),
        ["Username"] = target.Username, ["Email"] = target.Username + "@example.invalid",
        ["FullName"] = fullName, ["Password"] = password, ["IsActive"] = "true"
    };
    if (target.IsJury)
    {
        fields["Phone"] = "5550000000";
        fields["IsJuryPresident"] = "false";
        fields["RemovePhoto"] = "false";
    }
    using var response = await client.PostAsync(path, new FormUrlEncodedContent(fields));
    Check(response.IsSuccessStatusCode && response.RequestMessage?.RequestUri?.AbsolutePath == "/" + path,
        "Profile edit completes on its expected edit page.");
    return await response.Content.ReadAsStringAsync();
}
string Antiforgery(string html)
{
    // Authenticated pages also contain the shared logout form. Its token is
    // valid for the same antiforgery cookie and authenticated identity.
    var input = Inputs(html).First(attributes => attributes.GetValueOrDefault("name") == "__RequestVerificationToken");
    return input["value"];
}
IEnumerable<Dictionary<string, string>> Inputs(string html) =>
    Regex.Matches(html, @"<input\b[^>]*>", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)
        .Select(match => Attributes(match.Value));
Dictionary<string, string> Attributes(string tag) =>
    Regex.Matches(tag, "(?<name>[A-Za-z_:][A-Za-z0-9_:.-]*)(?:\\s*=\\s*(?:\"(?<value>[^\"]*)\"|'(?<value>[^']*)'))?",
        RegexOptions.CultureInvariant)
        .ToDictionary(match => match.Groups["name"].Value,
            match => WebUtility.HtmlDecode(match.Groups["value"].Value), StringComparer.OrdinalIgnoreCase);
void AssertPasswordUi(string html, string hash)
{
    var input = Inputs(html).Single(attributes => attributes.ContainsKey("data-edit-password-input"));
    Check(input.GetValueOrDefault("type") == "password" && input.GetValueOrDefault("value", "") == "",
        "Edit password input is masked and its actual submitted value starts empty.");
    Check(input.GetValueOrDefault("placeholder") == new string('•', 8) && !input.ContainsKey("required"),
        "Edit password uses a masked placeholder and remains optional.");
    var toggle = Regex.Matches(html, @"<button\b[^>]*>", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)
        .Select(match => Attributes(match.Value)).Single(attributes => attributes.ContainsKey("data-edit-password-toggle"));
    Check(toggle.ContainsKey("disabled") && toggle.GetValueOrDefault("aria-pressed") == "false",
        "The eye starts disabled without a replacement credential.");
    Check(!html.Contains(hash, StringComparison.Ordinal) && !html.Contains(WebUtility.HtmlEncode(hash), StringComparison.Ordinal) &&
          !html.Contains(oldPassword, StringComparison.Ordinal) && !html.Contains(WebUtility.HtmlEncode(oldPassword), StringComparison.Ordinal) &&
          !html.Contains(newPassword, StringComparison.Ordinal) && !html.Contains(WebUtility.HtmlEncode(newPassword), StringComparison.Ordinal),
        "Rendered edit HTML exposes neither stored hash nor old/new plaintext credentials.");
}

async Task TestSessions(HttpClient client, CookieContainer cookies, HttpResponseMessage loginResponse,
    DateTimeOffset loginStarted, string html)
{
    const string cookieName = "AfifeAdmin.Authentication";
    var current = ReadSession(html);
    var authCookie = cookies.GetCookies(baseAddress).Cast<Cookie>().Single(cookie => cookie.Name == cookieName);
    Check(AuthenticationCookies(loginResponse).Any(header => header.Contains("expires=", StringComparison.OrdinalIgnoreCase)) &&
          authCookie.Expires != DateTime.MinValue &&
          new DateTimeOffset(authCookie.Expires.ToUniversalTime()) > loginStarted.AddMinutes(9.5) &&
          new DateTimeOffset(authCookie.Expires.ToUniversalTime()) <= DateTimeOffset.UtcNow.AddMinutes(10),
        "Login sets a persistent browser cookie with the ten-minute server deadline.");
    Check(Math.Abs(new DateTimeOffset(authCookie.Expires.ToUniversalTime()).ToUnixTimeMilliseconds() - current.ExpiresAt) < 1500 &&
          current.ExpiresAt - current.ServerNow is > 590_000 and <= 600_000,
        "Rendered session metadata agrees with the cookie's ten-minute expiry.");
    Check(await context.SharedAdminDataProtectionKeys.AsNoTracking().AnyAsync(),
        "The actual HTTP process stores its Data Protection key ring in the disposable shared database.");
    var databaseBefore = await SessionDatabaseSnapshot();
    var protectedPath = $"admin-yonetimi/{adminId}/duzenle";

    using (var request = new HttpRequestMessage(HttpMethod.Get, protectedPath))
    {
        request.Headers.Add("X-Requested-With", "XMLHttpRequest");
        request.Headers.Add("Sec-Fetch-Mode", "cors");
        request.Headers.Add("Sec-Fetch-Dest", "empty");
        using var response = await client.SendAsync(request);
        var background = ReadSession(await response.Content.ReadAsStringAsync());
        Check(response.IsSuccessStatusCode && !AuthenticationCookies(response).Any() &&
              background.Id == current.Id && background.ExpiresAt == current.ExpiresAt,
            "Background XHR GET leaves the authentication cookie and idle deadline unchanged.");
    }
    using (var anonymousHandler = new HttpClientHandler { CookieContainer = new CookieContainer(), AllowAutoRedirect = false })
    using (var anonymous = new HttpClient(anonymousHandler) { BaseAddress = baseAddress })
    using (var response = await anonymous.PostAsync("oturum/aktivite", ActivityBody(current.Id, 0, false)))
        Check(response.StatusCode == HttpStatusCode.Unauthorized,
            "Anonymous activity receives HTTP 401 without a redirect or session renewal.");
    using (var response = await client.PostAsync("oturum/aktivite", ActivityBody(current.Id, 0, false)))
        Check(response.StatusCode == HttpStatusCode.BadRequest && !AuthenticationCookies(response).Any(),
            "Activity without antiforgery is rejected without renewing the cookie.");
    using (var response = await client.PostAsync("oturum/aktivite", ActivityBody(Guid.NewGuid().ToString("N"), 0, true)))
    {
        using var result = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Check(response.StatusCode == HttpStatusCode.BadRequest && result.RootElement.GetProperty("reload").GetBoolean() &&
              !AuthenticationCookies(response).Any(), "A different login session cannot renew the current session.");
    }
    foreach (var invalidAge in new long[] { -1, 60_001 })
    {
        using var response = await client.PostAsync("oturum/aktivite", ActivityBody(current.Id, invalidAge, true));
        Check(response.StatusCode == HttpStatusCode.BadRequest && !AuthenticationCookies(response).Any(),
            "Activity ages outside the accepted range cannot renew a cookie.");
    }
    using (var response = await client.PostAsync("oturum/aktivite", ActivityBody(current.Id, 30_000, true)))
    {
        var delayed = await ReadActivity(response);
        Check(response.IsSuccessStatusCode && delayed.Id == current.Id && delayed.ExpiresAt == current.ExpiresAt &&
              !AuthenticationCookies(response).Any(), "A delayed older action neither extends nor shortens confirmed activity.");
    }

    // AuthenticationProperties persist whole-second timestamps. Cross one
    // second to prove the real endpoint advances the deadline, without waiting
    // for the ten-minute expiration boundary covered by the signed-ticket test.
    await Task.Delay(1100);
    using (var response = await client.PostAsync("oturum/aktivite", ActivityBody(current.Id, 0, true)))
    {
        var renewed = await ReadActivity(response);
        Check(response.IsSuccessStatusCode && AuthenticationCookies(response).Any() &&
              renewed.Id == current.Id && renewed.ExpiresAt > current.ExpiresAt &&
              renewed.ExpiresAt - renewed.ServerNow is > 598_000 and <= 600_000,
            "A validated recent action renews the same session for ten minutes from actual activity.");
        current = renewed;
    }
    using (var request = new HttpRequestMessage(HttpMethod.Get, protectedPath))
    {
        request.Headers.Add("Sec-Fetch-Mode", "navigate");
        request.Headers.Add("Sec-Fetch-Dest", "document");
        request.Headers.Add("Sec-Fetch-User", "?1");
        using var response = await client.SendAsync(request);
        var navigated = ReadSession(await response.Content.ReadAsStringAsync());
        Check(response.IsSuccessStatusCode && AuthenticationCookies(response).Any() &&
              navigated.Id == current.Id && navigated.ExpiresAt >= current.ExpiresAt,
            "A browser navigation explicitly activated by the user renews the same session.");
        current = navigated;
    }
    Check(await SessionDatabaseSnapshot() == databaseBefore,
        "Session probes and activity renewal write no user, credential, audit, or shared-key records.");

    // Use the production key registration and framework ticket format instead
    // of guessing Data Protection purposes or sleeping for ten minutes.
    var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
    {
        ["ConnectionStrings:AfifeConnectionString"] = connectionString
    }).Build();
    var services = new ServiceCollection();
    services.AddLogging();
    services.AddSingleton<IConfiguration>(configuration);
    services.AddSharedAdminDataProtection(configuration);
    services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie();
    using (var provider = services.BuildServiceProvider())
    {
        var format = provider.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>()
            .Get(CookieAuthenticationDefaults.AuthenticationScheme).TicketDataFormat;
        authCookie = cookies.GetCookies(baseAddress).Cast<Cookie>().Single(cookie => cookie.Name == cookieName);
        var ticket = format.Unprotect(authCookie.Value);
        Check(ticket is not null && AdminSessionPolicy.GetSessionId(ticket.Properties) == current.Id,
            "An independent provider reads the HTTP cookie through the configured shared key ring.");
        var expiredProperties = AdminSessionPolicy.CreateProperties(DateTimeOffset.UtcNow.AddMinutes(-11), current.Id);
        var expired = format.Protect(new AuthenticationTicket(ticket!.Principal, expiredProperties,
            CookieAuthenticationDefaults.AuthenticationScheme));
        var expiredCookies = new CookieContainer();
        expiredCookies.Add(baseAddress, new Cookie(cookieName, expired, "/") { Expires = DateTime.UtcNow.AddMinutes(10) });
        using var expiredHandler = new HttpClientHandler { CookieContainer = expiredCookies, AllowAutoRedirect = false };
        using var expiredClient = new HttpClient(expiredHandler) { BaseAddress = baseAddress };
        using var request = new HttpRequestMessage(HttpMethod.Get, protectedPath);
        request.Headers.Add("X-Requested-With", "XMLHttpRequest");
        using var response = await expiredClient.SendAsync(request);
        Check(response.StatusCode == HttpStatusCode.Unauthorized,
            "The real server rejects a correctly protected but expired ticket while the browser still retains its cookie.");
    }

    await StopApplication();
    alternateContentRoot = Path.GetFullPath(Path.Combine(logDirectory, "workflow-contentroot-" + Guid.NewGuid().ToString("N")));
    if (!alternateContentRoot.StartsWith(Path.GetFullPath(logDirectory) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
        throw new InvalidOperationException("Alternate test content root escaped the diagnostics directory.");
    Directory.CreateDirectory(alternateContentRoot);
    start.ArgumentList.Add("--contentRoot");
    start.ArgumentList.Add(alternateContentRoot);
    StartApplication();
    await WaitForStartup(client);
    using (var response = await client.GetAsync(protectedPath))
    {
        var restarted = ReadSession(await response.Content.ReadAsStringAsync());
        Check(response.IsSuccessStatusCode && response.RequestMessage?.RequestUri?.AbsolutePath == "/" + protectedPath &&
              restarted.Id == current.Id && restarted.ExpiresAt == current.ExpiresAt && !AuthenticationCookies(response).Any(),
            "The same browser stays authenticated after a process restart with a different content root and shared database.");
    }
    Check(await SessionDatabaseSnapshot() == databaseBefore,
        "Restarting with existing shared keys preserves all credentials and creates no duplicate key or audit rows.");

    FormUrlEncodedContent ActivityBody(string id, long age, bool csrf) => new(new Dictionary<string, string>
    {
        ["sessionId"] = id, ["elapsedMilliseconds"] = age.ToString(CultureInfo.InvariantCulture),
        ["__RequestVerificationToken"] = csrf ? current.AntiforgeryToken! : ""
    });
    async Task<SessionState> ReadActivity(HttpResponseMessage response)
    {
        using var payload = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return new SessionState(payload.RootElement.GetProperty("sessionId").GetString()!,
            payload.RootElement.GetProperty("expiresAt").GetInt64(), payload.RootElement.GetProperty("serverNow").GetInt64(),
            current.AntiforgeryToken);
    }
}
IEnumerable<string> AuthenticationCookies(HttpResponseMessage response) =>
    response.Headers.TryGetValues("Set-Cookie", out var headers)
        ? headers.Where(header => header.StartsWith("AfifeAdmin.Authentication", StringComparison.Ordinal)) : [];
SessionState ReadSession(string html)
{
    var form = Regex.Matches(html, @"<form\b[^>]*>.*?</form>", RegexOptions.IgnoreCase | RegexOptions.Singleline)
        .Select(match => (Html: match.Value, Attributes: Attributes(Regex.Match(match.Value, @"<form\b[^>]*>").Value)))
        .Single(item => item.Attributes.ContainsKey("data-idle-session"));
    var state = new SessionState(form.Attributes["data-session-id"],
        long.Parse(form.Attributes["data-expires-at"], CultureInfo.InvariantCulture),
        long.Parse(form.Attributes["data-server-now"], CultureInfo.InvariantCulture), Antiforgery(form.Html));
    Check(Guid.TryParseExact(state.Id, "N", out _) && state.ExpiresAt > state.ServerNow &&
          Math.Abs(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - state.ServerNow) < 10_000,
        "Authenticated HTML provides a valid server-clock session ID, deadline and antiforgery token.");
    return state;
}
async Task<string> SessionDatabaseSnapshot() => JsonSerializer.Serialize(new
{
    Users = await context.Users.IgnoreQueryFilters().AsNoTracking().OrderBy(user => user.Id).ToArrayAsync(),
    UserLogs = await context.UserLogs.AsNoTracking().CountAsync(),
    AdminLogs = await context.AdminLogs.AsNoTracking().CountAsync(),
    JuryLogs = await context.JuryLogs.AsNoTracking().CountAsync(),
    Keys = await context.SharedAdminDataProtectionKeys.AsNoTracking().OrderBy(key => key.Id).ToArrayAsync()
});

async Task TestBulkReset(HttpClient client)
{
    var playId = Guid.NewGuid();
    var otherPlayId = Guid.NewGuid();
    var currentId = Guid.NewGuid();
    var historicalId = Guid.NewGuid();
    var activeId = Guid.NewGuid();
    var freshId = Guid.NewGuid();
    var otherCandidateId = Guid.NewGuid();
    var voteHistorical = Guid.NewGuid();
    var voteActive = Guid.NewGuid();
    var voteOtherJury = Guid.NewGuid();
    var voteOtherPlay = Guid.NewGuid();
    var now = DateTime.UtcNow;
    context.Plays.AddRange(PlayFixture(playId), PlayFixture(otherPlayId));
    await context.SaveChangesAsync();
    context.PlayAwardCategories.AddRange(
        CandidateFixture(currentId, playId, 1, true, true),
        CandidateFixture(historicalId, playId, 1, false, false),
        CandidateFixture(activeId, playId, 2, true, true),
        CandidateFixture(freshId, playId, 3, true, true),
        CandidateFixture(otherCandidateId, otherPlayId, 1, true, true));
    await context.SaveChangesAsync();
    context.JuryVotes.AddRange(
        VoteFixture(voteHistorical, historicalId, juryId, false),
        VoteFixture(voteActive, activeId, juryId, true),
        VoteFixture(voteOtherJury, activeId, otherId, true),
        VoteFixture(voteOtherPlay, otherCandidateId, juryId, true));
    await context.SaveChangesAsync();

    var historyPage = await Get(client, $"oylama-gecmisi?playId={playId}");
    var token = Antiforgery(historyPage);
    var cardsPath = $"oylama-gecmisi/kategoriler?playId={playId}&juryId={juryId}";
    var cards = await Get(client, cardsPath);
    var scope = Regex.Matches(cards, @"<div\b[^>]*>", RegexOptions.IgnoreCase)
        .Select(match => Attributes(match.Value)).Single(item => item.ContainsKey("data-voting-history-scope"));
    Check(Guid.Parse(scope["data-play-id"]) == playId && Guid.Parse(scope["data-jury-id"]) == juryId &&
          cards.Contains("data-reset-all-votes", StringComparison.Ordinal), "Voting cards and footer capture the selected jury/play scope.");
    var votedIds = Regex.Matches(cards, @"<(?:input|option)\b[^>]*>", RegexOptions.IgnoreCase)
        .Select(match => Attributes(match.Value)).Where(item => item.GetValueOrDefault("data-has-vote") == "true")
        .Select(item => Guid.Parse(item["value"])).Distinct().ToArray();
    Check(votedIds.Length == 2 && votedIds.Contains(historicalId) && votedIds.Contains(activeId),
        "Rendered snapshot includes voted historical dropdown and current hidden candidates.");

    var beforeRejected = await VoteSnapshot();
    using (var csrf = await client.PostAsync("oylama-gecmisi/tum-oylamalari-sifirla", BulkBody(votedIds, false)))
        Check(csrf.StatusCode == HttpStatusCode.BadRequest && await VoteSnapshot() == beforeRejected,
            "Bulk reset without antiforgery is rejected without changing votes.");
    using (var anonymousHandler = new HttpClientHandler { AllowAutoRedirect = false, CookieContainer = new CookieContainer() })
    using (var anonymous = new HttpClient(anonymousHandler) { BaseAddress = baseAddress })
    using (var challenge = await anonymous.PostAsync("oylama-gecmisi/tum-oylamalari-sifirla", BulkBody(votedIds, false)))
        Check((challenge.StatusCode == HttpStatusCode.Unauthorized ||
               challenge.StatusCode == HttpStatusCode.Found && challenge.Headers.Location?.ToString().Contains("/giris-yap", StringComparison.Ordinal) == true)
              && await VoteSnapshot() == beforeRejected, "Anonymous bulk reset challenges authentication without changing votes.");

    using (var reset = await client.PostAsync("oylama-gecmisi/tum-oylamalari-sifirla", BulkBody(votedIds, true)))
    {
        using var result = JsonDocument.Parse(await reset.Content.ReadAsStringAsync());
        Check(reset.IsSuccessStatusCode && result.RootElement.GetProperty("success").GetBoolean() &&
              result.RootElement.GetProperty("resetCount").GetInt32() == 2,
            "Authenticated JSON-array form payload resets the complete rendered candidate snapshot.");
    }
    Check(!await Published(voteHistorical) && !await Published(voteActive) &&
           await Published(voteOtherJury) && await Published(voteOtherPlay),
        "Bulk reset includes inactive historical votes and leaves another jury/play untouched.");
    cards = await Get(client, cardsPath);
    var footer = Regex.Matches(cards, @"<button\b[^>]*>", RegexOptions.IgnoreCase)
        .Select(match => Attributes(match.Value)).Single(item => item.ContainsKey("data-reset-all-votes"));
    Check(footer.ContainsKey("disabled"), "The refreshed footer is disabled when the selected scope has no votes.");

    var freshVote = Guid.NewGuid();
    context.JuryVotes.Add(VoteFixture(freshVote, freshId, juryId, true));
    await context.SaveChangesAsync();
    var beforeStale = await VoteSnapshot();
    using (var stale = await client.PostAsync("oylama-gecmisi/tum-oylamalari-sifirla", BulkBody([historicalId, freshId], true)))
        Check(stale.StatusCode == HttpStatusCode.BadRequest && await VoteSnapshot() == beforeStale,
            "Mixed stale/fresh bulk selection rolls back every vote change atomically.");
    using (var single = await client.PostAsync("oylama-gecmisi/oylamayi-sifirla", new FormUrlEncodedContent(new Dictionary<string, string>
    {
        ["__RequestVerificationToken"] = token, ["playId"] = playId.ToString(),
        ["juryId"] = juryId.ToString(), ["playAwardCategoryId"] = freshId.ToString()
    })))
        Check(single.IsSuccessStatusCode && !await Published(freshVote), "Existing single-vote reset remains functional.");
    Check((await Hashes()).OrderBy(pair => pair.Key).SequenceEqual(baselineHashes.OrderBy(pair => pair.Key)),
        "Voting history actions never change account credentials.");

    Play PlayFixture(Guid id) => new()
    {
        Id = id, PlayName = "Workflow play " + id.ToString("N"), TheaterName = "Workflow theatre",
        Slug = "workflow-" + id.ToString("N"), StatusCode = 1, CreatedAt = now,
        IsPublished = true, IsActive = true, JuriOylamaStatus = true, RecordType = false
    };
    PlayAwardCategory CandidateFixture(Guid id, Guid parent, int role, bool current, bool active) => new()
    {
        Id = id, PlayId = parent, Candidate = "Workflow actor " + id.ToString("N"),
        AwardCategoryCode = 1003, Role = "Workflow role", RoleCode = role,
        IsCurrent = current, IsActive = active, IsPublished = true, CreatedAt = now
    };
    JuryVote VoteFixture(Guid id, Guid candidate, Guid jury, bool active) => new()
    {
        Id = id, PlayAwardCategoryId = candidate, JuryId = jury, Score = 6,
        IsPublished = true, IsActive = active, CreatedAt = now
    };
    FormUrlEncodedContent BulkBody(Guid[] ids, bool csrf) => new(new Dictionary<string, string>
    {
        ["__RequestVerificationToken"] = csrf ? token : "", ["playId"] = playId.ToString(),
        ["juryId"] = juryId.ToString(), ["playAwardCategoryIdsJson"] = JsonSerializer.Serialize(ids)
    });
    async Task<bool> Published(Guid id) => await context.JuryVotes.IgnoreQueryFilters().AsNoTracking()
        .Where(vote => vote.Id == id).Select(vote => vote.IsPublished).SingleAsync();
    async Task<string> VoteSnapshot() => JsonSerializer.Serialize(await context.JuryVotes.IgnoreQueryFilters().AsNoTracking()
        .OrderBy(vote => vote.Id).Select(vote => new
        {
            vote.Id, vote.JuryId, vote.PlayAwardCategoryId, vote.IsPublished, vote.IsActive,
            vote.Score, vote.CreatedAt, vote.CreatedBy, vote.UpdatedAt, vote.UpdatedBy
        }).ToArrayAsync());
}
sealed record Target(Guid Id, string Username, string Route, bool IsJury);
sealed record SessionState(string Id, long ExpiresAt, long ServerNow, string? AntiforgeryToken);
