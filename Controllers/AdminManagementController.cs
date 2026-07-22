using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Reports;

namespace YKBAfife.Controllers;

public sealed class AdminManagementController(
    AfifeContext context,
    IAdminReportService adminReportService,
    IUserActivityLogger activityLogger) : Controller
{
    [HttpGet("admin-yonetimi")]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var report = await adminReportService.GetPageAsync(new AdminTableQuery(), cancellationToken);
        return View(new AdminManagementViewModel { Table = AdminComplexTableFactory.Create(report) });
    }

    [HttpPost("admin-yonetimi/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Table(
        [FromForm] AdminTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await adminReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = AdminComplexTableFactory.Create(report) });
    }

    [HttpPost("admin-yonetimi/{id:guid}/status")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateStatus(
        Guid id,
        [FromForm] bool isActive,
        CancellationToken cancellationToken)
    {
        var admin = await context.Users.SingleOrDefaultAsync(
            user => user.Id == id && user.IsPublished && user.RoleCode == 1,
            cancellationToken);
        if (admin is null) return NotFound();
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        var oldValue = admin.IsActive;
        admin.IsActive = isActive;
        admin.UpdatedAt = DateTime.UtcNow;
        admin.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.UserUpdated,
            true,
            admin.Id,
            admin.Username,
            currentUserId,
            details: "Admin aktiflik durumu g\u00fcncellendi.",
            oldValue: oldValue.ToString(),
            newValue: isActive.ToString(),
            cancellationToken: cancellationToken);

        return Json(new { isActive = admin.IsActive });
    }

    [HttpGet("admin-yonetimi/ekle")]
    public IActionResult Add()
    {
        var model = new AddAdminViewModel
        {
            Username = TempData["AddAdmin.Username"]?.ToString() ?? string.Empty,
            Email = TempData["AddAdmin.Email"]?.ToString() ?? string.Empty,
            FullName = TempData["AddAdmin.FullName"]?.ToString() ?? string.Empty,
            IsActive = !bool.TryParse(TempData["AddAdmin.IsActive"]?.ToString(), out var isActive) || isActive
        };
        return View(model);
    }

    [HttpPost("admin-yonetimi/ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Add(AddAdminViewModel model, CancellationToken cancellationToken)
    {
        Normalize(model);
        ModelState.Clear();
        TryValidateModel(model);

        if (!ModelState.IsValid)
        {
            return RedirectWithFailure(model, ValidationErrors());
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.RoleCode == 1 && user.Username == model.Username,
                cancellationToken))
        {
            return RedirectWithFailure(model, "Bu kullan\u0131c\u0131 ad\u0131 ba\u015fka bir admin taraf\u0131ndan kullan\u0131l\u0131yor.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.RoleCode == 1 && user.Email == model.Email,
                cancellationToken))
        {
            return RedirectWithFailure(model, "Bu e-posta adresi ba\u015fka bir admin taraf\u0131ndan kullan\u0131l\u0131yor.");
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        var fullNameParts = model.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var adminId = Guid.NewGuid();
        var admin = new User
        {
            Id = adminId,
            FirstName = string.Join(' ', fullNameParts[..^1]),
            LastName = fullNameParts[^1],
            Username = model.Username,
            Email = model.Email,
            PasswordHash = PasswordHashHelper.HashPassword(model.Password),
            CreatedAt = DateTime.UtcNow,
            CreatedBy = currentUserId,
            IsPublished = true,
            IsActive = model.IsActive!.Value,
            RoleCode = 1
        };
        context.Users.Add(admin);
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            context.Entry(admin).State = EntityState.Detached;
            return RedirectWithFailure(
                model,
                "KullanÄ±cÄ± adÄ± veya e-posta adresi baÅŸka bir admin tarafÄ±ndan kullanÄ±lÄ±yor.");
        }
        await activityLogger.LogAsync(
            UserActivityTypes.UserCreated,
            true,
            adminId,
            model.Username,
            currentUserId,
            details: "Yeni admin kullan\u0131c\u0131s\u0131 olu\u015fturuldu.",
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Admin ba\u015far\u0131yla kaydedildi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Index)) ?? "/admin-yonetimi";
        return RedirectToAction(nameof(Add));
    }

    [HttpGet("admin-yonetimi/{id:guid}")]
    public async Task<IActionResult> Details(Guid id, CancellationToken cancellationToken)
    {
        var admin = await context.Users
            .AsNoTracking()
            .Where(user => user.Id == id && user.IsPublished && user.RoleCode == 1)
            .Select(user => new
            {
                user.Id,
                user.Username,
                user.Email,
                FullName = (user.FirstName + " " + user.LastName).Trim(),
                user.IsActive,
                user.CreatedAt,
                user.CreatedBy
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (admin is null) return NotFound();

        var createdByName = admin.CreatedBy.HasValue
            ? await context.Users.AsNoTracking()
                .Where(user => user.Id == admin.CreatedBy.Value)
                .Select(user => (user.FirstName + " " + user.LastName).Trim())
                .SingleOrDefaultAsync(cancellationToken)
            : null;

        return View(new AdminDetailsViewModel
        {
            Id = admin.Id,
            Username = admin.Username,
            Email = admin.Email,
            FullName = admin.FullName,
            IsActive = admin.IsActive,
            CreatedAt = admin.CreatedAt,
            CreatedByName = createdByName ?? "-"
        });
    }

    private IActionResult RedirectWithFailure(AddAdminViewModel model, string message)
    {
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = message;
        TempData["AddAdmin.Username"] = model.Username;
        TempData["AddAdmin.Email"] = model.Email;
        TempData["AddAdmin.FullName"] = model.FullName;
        TempData["AddAdmin.IsActive"] = model.IsActive?.ToString();
        return RedirectToAction(nameof(Add));
    }

    private string ValidationErrors()
    {
        var messages = ModelState.Values
            .SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage)
            .Where(message => !string.IsNullOrWhiteSpace(message))
            .Distinct()
            .ToArray();
        return messages.Length > 0
            ? string.Join(Environment.NewLine, messages)
            : "Form alanlar\u0131n\u0131 kontrol ediniz.";
    }

    private static void Normalize(AddAdminViewModel model)
    {
        model.Username = model.Username?.Trim() ?? string.Empty;
        model.Email = model.Email?.Trim() ?? string.Empty;
        model.FullName = string.Join(' ', (model.FullName ?? string.Empty).Split(
            (char[]?)null,
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }
}
