using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;
using YKBAfife.Services.Audit;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    [AdminMutationAudit]
    [HttpPost("oylama-gecmisi/tum-oylamalari-sifirla")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetJuryVotes(
        Guid playId,
        Guid juryId,
        [FromForm] string? playAwardCategoryIdsJson,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
            return Unauthorized(new { success = false, message = "Oturum bilgisi doğrulanamadı." });

        Guid[]? playAwardCategoryIds;
        try
        {
            // One JSON form field avoids MVC's collection/value-count limits
            // while retaining the existing form-token antiforgery flow.
            playAwardCategoryIds = JsonSerializer.Deserialize<Guid[]>(playAwardCategoryIdsJson ?? "null");
        }
        catch (JsonException)
        {
            return BadRequest(new { success = false, message = "Oylama seçimi geçersiz." });
        }

        if (!ModelState.IsValid || playId == Guid.Empty || juryId == Guid.Empty ||
            playAwardCategoryIds is not { Length: > 0 } || playAwardCategoryIds.Contains(Guid.Empty))
            return BadRequest(new { success = false, message = "Sıfırlanabilecek bir oy bulunamadı." });

        var candidateIds = playAwardCategoryIds.Distinct().ToArray();
        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        var now = TurkeyTime.Now;

        // Keep the existing single-reset eligibility predicate: historical,
        // inactive votes/candidates remain resettable when they are published.
        // One SQL UPDATE invokes ranking/audit triggers once for the whole set.
        var affected = await context.JuryVotes
            .Where(vote => vote.JuryId == juryId && vote.IsPublished &&
                candidateIds.Contains(vote.PlayAwardCategoryId) &&
                context.PlayAwardCategories.Any(candidate =>
                    candidate.Id == vote.PlayAwardCategoryId &&
                    candidate.PlayId == playId && candidate.IsPublished))
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(vote => vote.IsPublished, false)
                .SetProperty(vote => vote.UpdatedAt, now)
                .SetProperty(vote => vote.UpdatedBy, currentUserId), cancellationToken);

        // A stale/mismatched ID rolls back the entire UPDATE and its trigger
        // changes, including audit rows; no partial bulk reset can be committed.
        if (affected != candidateIds.Length)
        {
            await transaction.RollbackAsync(cancellationToken);
            return BadRequest(new
            {
                success = false,
                message = "Oylama bilgileri değişmiş olabilir. Ekranı yenileyip tekrar deneyin."
            });
        }

        await transaction.CommitAsync(cancellationToken);
        return Json(new
        {
            success = true,
            resetCount = affected,
            message = $"{affected} oylama başarıyla sıfırlandı."
        });
    }
}
