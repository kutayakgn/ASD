using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Authentication;

namespace YKBAfife.Controllers;

public sealed class AccountController(
    IAdminAuthenticationService authenticationService,
    IUserActivityLogger activityLogger,
    TimeProvider clock) : Controller
{
    [AllowAnonymous]
    [HttpGet("giris-yap")]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToAction("Index", "Home");
        }

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [AllowAnonymous]
    [HttpPost("giris-yap")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel model, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var admin = await authenticationService.AuthenticateAsync(
            model.Username,
            model.Password,
            cancellationToken);

        if (admin is null)
        {
            ModelState.AddModelError(string.Empty, "Kullanıcı adı veya şifre hatalı.");
            return View(model);
        }

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, admin.UserId.ToString()),
            new Claim(ClaimTypes.Name, admin.FullName),
            new Claim(ClaimTypes.Role, "Coordinator"),
            new Claim("username", admin.Username)
        };

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var properties = AdminSessionPolicy.CreateProperties(clock.GetUtcNow());

        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            properties);

        if (!string.IsNullOrWhiteSpace(model.ReturnUrl) && Url.IsLocalUrl(model.ReturnUrl))
        {
            return LocalRedirect(model.ReturnUrl);
        }

        return RedirectToAction("Index", "Home");
    }

    [Authorize]
    [HttpPost("oturum/aktivite")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Activity(string? sessionId, long elapsedMilliseconds = 0)
    {
        if (!ModelState.IsValid || elapsedMilliseconds is < 0 or > 60_000)
            return BadRequest();
        var authentication = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        var now = clock.GetUtcNow();
        if (!authentication.Succeeded || authentication.Principal is null || authentication.Properties is null ||
            !AdminSessionPolicy.IsValid(authentication.Properties, now))
            return Unauthorized();
        if (sessionId != AdminSessionPolicy.GetSessionId(authentication.Properties))
            return BadRequest(new { reload = true });

        // A throttled event carries its age, so sending it later does not add
        // idle time. Never move the current ticket's confirmed activity back.
        var activityUtc = now.AddMilliseconds(-elapsedMilliseconds);
        var properties = authentication.Properties;
        if (activityUtc > properties.IssuedUtc)
        {
            properties = AdminSessionPolicy.CreateProperties(activityUtc, sessionId);
            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
                authentication.Principal, properties);
        }
        return Json(new
        {
            sessionId,
            expiresAt = properties.ExpiresUtc!.Value.ToUnixTimeMilliseconds(),
            serverNow = now.ToUnixTimeMilliseconds()
        });
    }

    [Authorize]
    [HttpPost("cikis-yap")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        var userId = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedUserId)
            ? parsedUserId
            : (Guid?)null;
        await activityLogger.LogAsync(
            UserActivityTypes.Logout,
            true,
            userId,
            User.FindFirstValue("username"),
            userId,
            details: "Kullanıcı yönetim panelinden çıkış yaptı.",
            cancellationToken: cancellationToken);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }
}
