using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using YKBAfife.Helpers;
using YKBAfife.Models.Components;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Reports;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    [HttpPost("diger-ayarlar/gruplar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> GroupSettingsTable(CancellationToken cancellationToken) =>
        ViewComponent("ComplexTable", new { model = await CreateGroupSettingsTableAsync(cancellationToken) });

    private async Task<ComplexTableViewModel> CreateGroupSettingsTableAsync(CancellationToken cancellationToken)
    {
        var rows = await context.Groups.AsNoTracking()
            .Where(group => group.IsPublished)
            .OrderBy(group => group.Code)
            .Select(group => new GroupSettingsRowViewModel
            {
                Id = group.Id,
                Code = group.Code,
                GroupName = group.GroupName
            }).ToArrayAsync(cancellationToken);
        return GroupSettingsComplexTableFactory.Create(rows);
    }

    [Authorize(Roles = "Coordinator")]
    [HttpGet("diger-ayarlar/gruplar/ekle")]
    public IActionResult AddGroup() => View(new GroupFormViewModel());

    [Authorize(Roles = "Coordinator")]
    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/gruplar/ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddGroup(GroupFormViewModel model, CancellationToken cancellationToken)
    {
        model.GroupName = model.GroupName?.Trim() ?? string.Empty;
        await ValidateGroupCodeAsync(model, cancellationToken);
        if (!ModelState.IsValid) return GroupValidationView(model);
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorId)) return Challenge();

        var group = new Group
        {
            Id = Guid.NewGuid(),
            Code = model.Code!.Value,
            GroupName = model.GroupName,
            CreatedAt = TurkeyTime.Now,
            CreatedBy = actorId,
            IsPublished = true
        };
        context.Groups.Add(group);
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception)
        {
            logger.LogWarning(exception, "Jüri grubu eklenemedi. Code: {Code}", model.Code);
            ModelState.AddModelError(IsDuplicateGroupCode(exception) ? nameof(model.Code) : string.Empty,
                IsDuplicateGroupCode(exception)
                    ? "Bu grup kodu zaten kullanılıyor. Silinmiş grupların kodları da tekrar kullanılamaz."
                    : "Grup eklenemedi. Lütfen tekrar deneyiniz.");
            return GroupValidationView(model);
        }

        return GroupSaved("Grup başarıyla eklendi.");
    }

    [Authorize(Roles = "Coordinator")]
    [HttpGet("diger-ayarlar/gruplar/{id:guid}/duzenle")]
    public async Task<IActionResult> EditGroup(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Groups.AsNoTracking()
            .Where(group => group.Id == id && group.IsPublished)
            .Select(group => new GroupFormViewModel { Id = group.Id, Code = group.Code, GroupName = group.GroupName })
            .SingleOrDefaultAsync(cancellationToken);
        return model is null ? NotFound() : View(model);
    }

    [Authorize(Roles = "Coordinator")]
    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/gruplar/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditGroup(Guid id, GroupFormViewModel model, CancellationToken cancellationToken)
    {
        if (model.Id != Guid.Empty && model.Id != id) return BadRequest();
        model.Id = id;
        model.GroupName = model.GroupName?.Trim() ?? string.Empty;
        if (!await context.Groups.AsNoTracking().AnyAsync(group => group.Id == id && group.IsPublished, cancellationToken))
            return NotFound();
        await ValidateGroupCodeAsync(model, cancellationToken);
        if (!ModelState.IsValid) return GroupValidationView(model);
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorId)) return Challenge();

        await using var transaction = await context.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        try
        {
            var group = await LoadGroupForMutationAsync(id, cancellationToken);
            if (group is null) return NotFound();
            if (group.Code == model.Code && group.GroupName == model.GroupName)
            {
                ModelState.AddModelError(string.Empty, "Herhangi bir değişiklik yapmadınız.");
                return GroupValidationView(model);
            }

            // Code is an EF alternate key. Update it in one SQL statement so the
            // database's ON UPDATE CASCADE preserves every dependent reference.
            var now = TurkeyTime.Now;
            await context.Groups.Where(item => item.Id == id && item.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.Code, model.Code!.Value)
                    .SetProperty(item => item.GroupName, model.GroupName)
                    .SetProperty(item => item.UpdatedAt, now)
                    .SetProperty(item => item.UpdatedBy, actorId), cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is SqlException or DbUpdateException)
        {
            await DisposeFailedGroupTransactionAsync(transaction, cancellationToken);
            logger.LogWarning(exception, "Jüri grubu güncellenemedi. GroupId: {GroupId}", id);
            ModelState.AddModelError(IsDuplicateGroupCode(exception) ? nameof(model.Code) : string.Empty,
                IsDuplicateGroupCode(exception)
                    ? "Bu grup kodu zaten kullanılıyor. Silinmiş grupların kodları da tekrar kullanılamaz."
                    : "Grup güncellenemedi. Kayıt başka bir işlemde değişmiş olabilir; lütfen tekrar deneyiniz.");
            return GroupValidationView(model);
        }
        return GroupSaved("Grup başarıyla güncellendi.");
    }

    [Authorize(Roles = "Coordinator")]
    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/gruplar/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteGroup(Guid id, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var actorId)) return Challenge();
        await using var transaction = await context.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        try
        {
            var group = await LoadGroupForMutationAsync(id, cancellationToken);
            if (group is null) return NotFound();
            var blockers = await GroupDeletionBlockersAsync(group.Code, cancellationToken);
            if (blockers.Length > 0)
                return Conflict(new { success = false, message = blockers });

            var now = TurkeyTime.Now;
            await context.Groups.Where(item => item.Id == id && item.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.IsPublished, false)
                    .SetProperty(item => item.UpdatedAt, now)
                    .SetProperty(item => item.UpdatedBy, actorId), cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Json(new { success = true, message = "Grup başarıyla silindi.", refreshTable = true });
        }
        catch (Exception exception) when (exception is SqlException or DbUpdateException)
        {
            await DisposeFailedGroupTransactionAsync(transaction, cancellationToken);
            logger.LogWarning(exception, "Jüri grubu silinemedi. GroupId: {GroupId}", id);
            var code = await context.Groups.IgnoreQueryFilters().AsNoTracking()
                .Where(group => group.Id == id).Select(group => (int?)group.Code)
                .SingleOrDefaultAsync(cancellationToken);
            var blockers = code.HasValue ? await GroupDeletionBlockersAsync(code.Value, cancellationToken) : string.Empty;
            return Conflict(new
            {
                success = false,
                message = blockers.Length > 0 ? blockers :
                    "Grup silinemedi. Bağlı kayıtlar veya eşzamanlı bir değişiklik olabilir; lütfen kontrol edip tekrar deneyiniz."
            });
        }
    }

    private Task<Group?> LoadGroupForMutationAsync(Guid id, CancellationToken cancellationToken) =>
        context.Groups.FromSqlInterpolated($"SELECT * FROM dbo.[Group] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {id}")
            .AsNoTracking().SingleOrDefaultAsync(group => group.IsPublished, cancellationToken);

    private async Task ValidateGroupCodeAsync(GroupFormViewModel model, CancellationToken cancellationToken)
    {
        if (model.Code.HasValue && await context.Groups.IgnoreQueryFilters().AsNoTracking()
            .AnyAsync(group => group.Id != model.Id && group.Code == model.Code.Value, cancellationToken))
            ModelState.AddModelError(nameof(model.Code),
                "Bu grup kodu zaten kullanılıyor. Silinmiş grupların kodları da tekrar kullanılamaz.");
    }

    private async Task<string> GroupDeletionBlockersAsync(int code, CancellationToken cancellationToken)
    {
        var members = await context.Users.IgnoreQueryFilters().AsNoTracking()
            .Where(user => user.GroupCode == code && user.RoleCode == 2 && user.IsPublished)
            .OrderBy(user => user.FirstName).ThenBy(user => user.LastName).ThenBy(user => user.Username)
            .Select(user => new { user.FirstName, user.LastName, user.Username })
            .ToArrayAsync(cancellationToken);
        if (members.Length == 0) return string.Empty;
        return string.Join("\n", members.Select(user => $"{user.FirstName} {user.LastName} ({user.Username})")) +
            $"\n\nBu kullanıcılar {code} kodlu gruba dahil olduğu için bu grup silinemez. Lütfen önce ilgili jürilerin grupla ilişiğini kesin.";
    }

    private IActionResult GroupValidationView(GroupFormViewModel model)
    {
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = ModelState.Values.SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage).FirstOrDefault(message => !string.IsNullOrWhiteSpace(message))
            ?? "Grup alanlarını kontrol ediniz.";
        return View(model);
    }

    private IActionResult GroupSaved(string message)
    {
        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = message;
        return RedirectToAction(nameof(VotingSettings));
    }

    private static bool IsDuplicateGroupCode(Exception exception)
    {
        for (Exception? current = exception; current is not null; current = current.InnerException)
            if (current is SqlException sql && sql.Errors.Cast<SqlError>().Any(error => error.Number is 2601 or 2627))
                return true;
        return false;
    }

    private static async Task DisposeFailedGroupTransactionAsync(
        IDbContextTransaction transaction, CancellationToken cancellationToken)
    {
        if (transaction.GetDbTransaction().Connection is not null)
            await transaction.RollbackAsync(cancellationToken);
        await transaction.DisposeAsync();
    }
}
