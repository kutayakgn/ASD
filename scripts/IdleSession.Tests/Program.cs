using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using YKBAfife.Services.Authentication;

var origin = new DateTimeOffset(2026, 10, 23, 10, 0, 0, TimeSpan.Zero);
var assertions = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    assertions++;
}

(CookieValidatePrincipalContext Context, FakeAuthentication Auth) ContextFor(AuthenticationProperties properties,
    string method = "GET", bool navigation = false, bool ajax = false)
{
    var auth = new FakeAuthentication();
    var http = new DefaultHttpContext
    {
        RequestServices = new ServiceCollection().AddSingleton<IAuthenticationService>(auth).BuildServiceProvider()
    };
    http.Request.Method = method;
    http.Request.Path = "/juriler";
    if (navigation)
    {
        http.Request.Headers["Sec-Fetch-Mode"] = "navigate";
        http.Request.Headers["Sec-Fetch-Dest"] = "document";
        http.Request.Headers["Sec-Fetch-User"] = "?1";
    }
    if (ajax) http.Request.Headers["X-Requested-With"] = "XMLHttpRequest";
    var scheme = new AuthenticationScheme("Cookies", null, typeof(CookieAuthenticationHandler));
    var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())], "Regression"));
    return (new CookieValidatePrincipalContext(http, scheme, new CookieAuthenticationOptions(), new AuthenticationTicket(principal, properties, scheme.Name)), auth);
}

var properties = AdminSessionPolicy.CreateProperties(origin);
Check(AdminSessionPolicy.Lifetime == TimeSpan.FromMinutes(10), "Idle lifetime must be exactly ten minutes.");
Check(properties.IsPersistent && properties.IssuedUtc == origin && properties.ExpiresUtc == origin.AddMinutes(10),
    "The persistent cookie must expire ten minutes after real activity, even if the browser closes.");
Check(AdminSessionPolicy.TryGetDeadline(properties, out var deadline) && deadline == origin.AddMinutes(10), "Policy must expose the signed deadline.");
var sessionId = properties.Items[AdminSessionPolicy.SessionIdKey]!;
Check(Guid.TryParseExact(sessionId, "N", out _), "Session IDs must be independent valid nonces.");
Check(AdminSessionPolicy.CreateProperties(origin).Items[AdminSessionPolicy.SessionIdKey] != sessionId, "A new login must create a new session ID.");
Check(AdminSessionPolicy.CreateProperties(origin.AddMinutes(1), sessionId).Items[AdminSessionPolicy.SessionIdKey] == sessionId,
    "Activity renewal must preserve the session ID.");

var clock = new FakeTimeProvider(origin.AddMinutes(9).AddSeconds(59));
var events = new AdminCookieAuthenticationEvents(clock);
var background = ContextFor(properties, ajax: true);
await events.ValidatePrincipal(background.Context);
Check(background.Context.Principal is not null && background.Auth.SignOuts == 0, "A cookie remains valid at 9:59.");
Check(!background.Context.ShouldRenew && properties.ExpiresUtc == deadline && properties.IssuedUtc == origin,
    "Polling must not slide the idle window.");
clock.Advance(TimeSpan.FromSeconds(1));
await events.ValidatePrincipal(background.Context);
Check(background.Context.Principal is null && background.Auth.SignOuts == 1 && !background.Context.ShouldRenew,
    "At exactly 10:00 the cookie must be rejected and signed out.");

clock.Set(origin.AddMinutes(4));
var navigationProperties = AdminSessionPolicy.CreateProperties(origin, sessionId);
var navigation = ContextFor(navigationProperties, navigation: true);
await events.ValidatePrincipal(navigation.Context);
Check(navigation.Context.Principal is not null && navigation.Context.ShouldRenew && navigation.Auth.SignOuts == 0,
    "A browser-confirmed top-level user navigation must renew a live session.");
Check(navigationProperties.IssuedUtc == clock.GetUtcNow() && navigationProperties.ExpiresUtc == clock.GetUtcNow().AddMinutes(10) && navigationProperties.IsPersistent,
    "Trusted navigation must issue a new ten-minute persistent deadline.");
Check(navigationProperties.Items[AdminSessionPolicy.SessionIdKey] == sessionId, "Navigation renewal must preserve the session nonce.");

foreach (var mode in new[] { "background", "unactivated-document", "iframe", "head", "post" })
{
    var current = AdminSessionPolicy.CreateProperties(origin);
    var check = ContextFor(current, method: mode == "head" ? "HEAD" : mode == "post" ? "POST" : "GET", navigation: mode != "background");
    if (mode == "unactivated-document") check.Context.Request.Headers.Remove("Sec-Fetch-User");
    if (mode == "iframe") check.Context.Request.Headers["Sec-Fetch-Dest"] = "iframe";
    await events.ValidatePrincipal(check.Context);
    Check(check.Context.Principal is not null && !check.Context.ShouldRenew && current.ExpiresUtc == origin.AddMinutes(10),
        $"{mode} must not extend inactivity.");
}

clock.Set(origin.AddMinutes(10));
var expiredNavigation = ContextFor(AdminSessionPolicy.CreateProperties(origin), navigation: true);
await events.ValidatePrincipal(expiredNavigation.Context);
Check(expiredNavigation.Context.Principal is null && !expiredNavigation.Context.ShouldRenew, "A navigation must not revive an already expired cookie.");

clock.Set(origin.AddMinutes(1));
var legacy = new AuthenticationProperties { IsPersistent = true, IssuedUtc = origin, ExpiresUtc = origin.AddHours(8) };
var badDuration = AdminSessionPolicy.CreateProperties(origin);
badDuration.ExpiresUtc = origin.AddHours(8);
var badVersion = AdminSessionPolicy.CreateProperties(origin);
badVersion.Items[AdminSessionPolicy.VersionKey] = "old";
var badId = AdminSessionPolicy.CreateProperties(origin);
badId.Items[AdminSessionPolicy.SessionIdKey] = "invalid";
var noIssued = AdminSessionPolicy.CreateProperties(origin);
noIssued.IssuedUtc = null;
var noExpires = AdminSessionPolicy.CreateProperties(origin);
noExpires.ExpiresUtc = null;
foreach (var invalid in new[] { legacy, badDuration, badVersion, badId, noIssued, noExpires })
{
    Check(!AdminSessionPolicy.TryGetDeadline(invalid, out _), "Legacy or malformed ticket must not expose a valid idle deadline.");
    var check = ContextFor(invalid, navigation: true);
    await events.ValidatePrincipal(check.Context);
    Check(check.Context.Principal is null && check.Auth.SignOuts == 1, "Legacy/malformed cookies must be rejected even during navigation.");
}
var future = ContextFor(AdminSessionPolicy.CreateProperties(origin.AddMinutes(3)));
await events.ValidatePrincipal(future.Context);
Check(future.Context.Principal is null, "A ticket issued too far in the future must not become a long-lived session.");

var ajaxRedirect = ContextFor(AdminSessionPolicy.CreateProperties(origin), ajax: true);
var redirect = new RedirectContext<CookieAuthenticationOptions>(ajaxRedirect.Context.HttpContext, ajaxRedirect.Context.Scheme,
    new CookieAuthenticationOptions(), ajaxRedirect.Context.Properties, "/giris-yap");
await events.RedirectToLogin(redirect);
Check(redirect.Response.StatusCode == 401 && !redirect.Response.Headers.ContainsKey("Location"), "AJAX expiry must be 401 rather than login HTML.");
await events.RedirectToAccessDenied(redirect);
Check(redirect.Response.StatusCode == 403, "AJAX access denial must be 403.");
var activityRedirect = ContextFor(AdminSessionPolicy.CreateProperties(origin));
activityRedirect.Context.Request.Path = "/oturum/aktivite";
var activity = new RedirectContext<CookieAuthenticationOptions>(activityRedirect.Context.HttpContext, activityRedirect.Context.Scheme,
    new CookieAuthenticationOptions(), activityRedirect.Context.Properties, "/giris-yap");
await events.RedirectToLogin(activity);
Check(activity.Response.StatusCode == 401, "The activity endpoint must return 401 without relying on an AJAX header.");
Console.WriteLine($"PASS: {assertions} idle-session policy/event assertions (9:59/10:00 boundary, navigation, background and persistent expiry).");

sealed class FakeTimeProvider(DateTimeOffset initial) : TimeProvider
{
    private DateTimeOffset now = initial;
    public override DateTimeOffset GetUtcNow() => now;
    public void Advance(TimeSpan amount) => now += amount;
    public void Set(DateTimeOffset value) => now = value;
}

sealed class FakeAuthentication : IAuthenticationService
{
    public int SignOuts { get; private set; }
    public Task<AuthenticateResult> AuthenticateAsync(HttpContext context, string? scheme) => Task.FromResult(AuthenticateResult.NoResult());
    public Task ChallengeAsync(HttpContext context, string? scheme, AuthenticationProperties? properties) => Task.CompletedTask;
    public Task ForbidAsync(HttpContext context, string? scheme, AuthenticationProperties? properties) => Task.CompletedTask;
    public Task SignInAsync(HttpContext context, string? scheme, ClaimsPrincipal principal, AuthenticationProperties? properties) => Task.CompletedTask;
    public Task SignOutAsync(HttpContext context, string? scheme, AuthenticationProperties? properties) { SignOuts++; return Task.CompletedTask; }
}
