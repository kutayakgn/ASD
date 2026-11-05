using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    private async Task<BirthdaySettingsViewModel> LoadBirthdaySettingsAsync(CancellationToken cancellationToken)
    {
        var configValue = await context.Configs.AsNoTracking()
            .Where(item => item.ConfigName == BirthdaySettings.ConfigName)
            .OrderBy(item => item.CreatedAt)
            .ThenBy(item => item.Id)
            .Select(item => item.ConfigValue)
            .FirstOrDefaultAsync(cancellationToken);

        return BirthdaySettings.Parse(configValue);
    }

    [Authorize(Roles = "Coordinator")]
    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/dogum-gunu-ayarlari")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SaveBirthdaySettings(
        [FromForm] BirthdaySettingsViewModel model,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId) ||
            currentUserId == Guid.Empty)
            return Challenge();

        if (ModelState.IsValid && BirthdaySettings.Serialize(model).Length > BirthdaySettings.MaximumConfigValueLength)
        {
            ModelState.AddModelError(nameof(model.Message),
                "Mesaj kaydedilemeyecek kadar uzun. Lütfen mesajı kısaltınız.");
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                success = false,
                message = "Lütfen mesajı ve gösterim süresini kontrol ediniz.",
                errors = ModelState.Where(item => item.Value?.Errors.Count > 0)
                    .ToDictionary(item => item.Key, item => item.Value!.Errors
                        .Select(error => string.IsNullOrEmpty(error.ErrorMessage)
                            ? "Geçerli bir tam sayı giriniz."
                            : error.ErrorMessage)
                        .ToArray())
            });
        }

        var configValue = BirthdaySettings.Serialize(model);
        // ConfigName's existing unique index only covers the home page table settings.
        // Serialize the lookup and insert so simultaneous first saves cannot create duplicate rows.
        await using var transaction = await context.Database.BeginTransactionAsync(
            IsolationLevel.Serializable, cancellationToken);
        try
        {
            var configs = await context.Configs.IgnoreQueryFilters()
                .Where(item => item.ConfigName == BirthdaySettings.ConfigName)
                .Take(2)
                .ToListAsync(cancellationToken);
            if (configs.Count > 1)
            {
                logger.LogWarning("Doğum günü ayarları kaydedilemedi: birden fazla BirthdaySettings kaydı var.");
                return Conflict(new
                {
                    success = false,
                    message = "Birden fazla doğum günü ayarı kaydı bulundu. Lütfen kayıtları kontrol ediniz."
                });
            }

            var config = configs.SingleOrDefault();
            var now = TurkeyTime.Now;
            if (config is null)
            {
                config = new Config
                {
                    Id = Guid.NewGuid(),
                    ConfigName = BirthdaySettings.ConfigName,
                    CreatedAt = now,
                    CreatedBy = currentUserId
                };
                context.Configs.Add(config);
            }

            config.ConfigValue = configValue;
            config.IsPublished = true;
            config.UpdatedAt = now;
            config.UpdatedBy = currentUserId;

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Json(new { success = true, message = "Doğum günü ayarları kaydedildi." });
        }
        catch (Exception exception) when (exception is SqlException or DbUpdateException)
        {
            logger.LogError(exception, "Doğum günü ayarları kaydedilemedi.");
            return Conflict(new
            {
                success = false,
                message = "Doğum günü ayarları kaydedilemedi. Lütfen tekrar deneyiniz."
            });
        }
    }
}
