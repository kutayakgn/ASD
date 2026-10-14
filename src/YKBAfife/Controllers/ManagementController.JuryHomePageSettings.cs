using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;
using YKBAfife.Services.Audit;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    [Authorize(Roles = "Coordinator")]
    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/juri-ana-ekran-tablolari/{configName}/status")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateJuryHomePageTableStatus(
        string configName,
        [FromForm] bool? isActive,
        CancellationToken cancellationToken)
    {
        if (!JuryHomePageTableSettings.IsKnown(configName)) return NotFound();
        if (!ModelState.IsValid || !isActive.HasValue)
        {
            return BadRequest(new
            {
                success = false,
                message = "Tablo statüsü true veya false olmalıdır."
            });
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
            return Challenge();

        var config = await context.Configs.SingleOrDefaultAsync(
            item => item.ConfigName == configName && item.IsPublished,
            cancellationToken);
        if (config is null) return NotFound();

        var configValue = isActive.Value ? "true" : "false";
        if (string.Equals(config.ConfigValue, configValue, StringComparison.Ordinal))
            return Json(new { success = true, isActive = isActive.Value });

        config.ConfigValue = configValue;
        config.UpdatedAt = TurkeyTime.Now;
        config.UpdatedBy = currentUserId;

        try
        {
            await context.SaveChangesAsync(cancellationToken);
            return Json(new { success = true, isActive = isActive.Value });
        }
        catch (DbUpdateException exception)
        {
            logger.LogError(exception,
                "Jüri paneli ana ekran tablo statüsü güncellenemedi. ConfigName: {ConfigName}", configName);
            return Conflict(new
            {
                success = false,
                message = "Tablo statüsü güncellenemedi. Lütfen tekrar deneyiniz."
            });
        }
    }
}
