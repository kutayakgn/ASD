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
    IUserActivityLogger activityLogger) : Controller
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
            ModelState.AddModelError(string.Empty, "Kullan\u0131c\u0131 ad\u0131 veya \u015fifre hatal\u0131.");
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
        var properties = new AuthenticationProperties
        {
            IsPersistent = model.RememberMe,
            AllowRefresh = true
        };

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
    [HttpGet("sifre-degistir")]
    public IActionResult ChangePassword() => View(new ChangePasswordViewModel());

    [Authorize]
    [HttpPost("sifre-degistir")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(
        ChangePasswordViewModel model,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdValue, out var userId))
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        var result = await authenticationService.ChangePasswordAsync(
            userId,
            model.CurrentPassword,
            model.NewPassword,
            cancellationToken);

        if (result == ChangePasswordResult.CurrentPasswordIncorrect)
        {
            ModelState.AddModelError(nameof(model.CurrentPassword), "Mevcut \u015fifreniz hatal\u0131.");
            return View(model);
        }

        if (result == ChangePasswordResult.UserNotFound)
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        TempData["PasswordChanged"] = "\u015eifreniz ba\u015far\u0131yla g\u00fcncellendi.";
        return RedirectToAction(nameof(ChangePassword));
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
            details: "Kullan\u0131c\u0131 y\u00f6netim panelinden \u00e7\u0131k\u0131\u015f yapt\u0131.",
            cancellationToken: cancellationToken);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }
}