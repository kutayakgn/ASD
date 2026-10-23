using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace YKBAfife.Services.Authentication;

public sealed class AdminCookieAuthenticationEvents(TimeProvider clock) : CookieAuthenticationEvents
{
    public override async Task ValidatePrincipal(CookieValidatePrincipalContext context)
    {
        var now = clock.GetUtcNow();
        if (!AdminSessionPolicy.IsValid(context.Properties, now))
        {
            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(context.Scheme.Name);
            return;
        }

        // Fetches, report polling and static resources do not prove activity.
        // Browsers mark document navigation activated by the user explicitly.
        var request = context.Request;
        if (HttpMethods.IsGet(request.Method) &&
            request.Headers["Sec-Fetch-Mode"] == "navigate" &&
            request.Headers["Sec-Fetch-Dest"] == "document" &&
            request.Headers["Sec-Fetch-User"] == "?1")
        {
            context.Properties.IssuedUtc = now;
            context.Properties.ExpiresUtc = now.Add(AdminSessionPolicy.Lifetime);
            context.Properties.IsPersistent = true;
            context.ShouldRenew = true;
        }
    }

    public override Task RedirectToLogin(RedirectContext<CookieAuthenticationOptions> context)
    {
        if (IsAjax(context.Request)) context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        else context.Response.Redirect(context.RedirectUri);
        return Task.CompletedTask;
    }

    public override Task RedirectToAccessDenied(RedirectContext<CookieAuthenticationOptions> context)
    {
        if (IsAjax(context.Request)) context.Response.StatusCode = StatusCodes.Status403Forbidden;
        else context.Response.Redirect(context.RedirectUri);
        return Task.CompletedTask;
    }

    private static bool IsAjax(HttpRequest request) =>
        request.Path.StartsWithSegments("/oturum/aktivite") ||
        request.Headers["X-Requested-With"] == "XMLHttpRequest";
}
