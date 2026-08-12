using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    private async Task<IActionResult> CandidateDetailsCoreAsync(Guid id, CancellationToken cancellationToken)
    {
        var data = await (
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join play in context.Plays.AsNoTracking() on candidate.PlayId equals play.Id
            join category in context.AwardCategories.AsNoTracking()
                on candidate.AwardCategoryCode equals category.CategoryCode
            where candidate.Id == id && candidate.IsPublished && play.IsPublished && category.IsPublished
            select new
            {
                Candidate = candidate,
                Play = play,
                category.CategoryName,
                category.HasRoleAndPhoto
            }).SingleOrDefaultAsync(cancellationToken);
        if (data is null) return NotFound();

        var auditUserIds = new[] { data.Candidate.CreatedBy, data.Candidate.UpdatedBy }
            .Where(userId => userId.HasValue)
            .Select(userId => userId!.Value)
            .Distinct()
            .ToArray();
        var auditUsers = await context.Users.AsNoTracking()
            .Where(user => auditUserIds.Contains(user.Id) && user.IsPublished)
            .ToDictionaryAsync(
                user => user.Id,
                user => (user.FirstName + " " + user.LastName).Trim(),
                cancellationToken);

        var hasPhoto = data.Candidate.PhotoImageId.HasValue && await context.Images.AsNoTracking()
            .AnyAsync(image => image.Id == data.Candidate.PhotoImageId.Value && image.IsPublished, cancellationToken);

        return View(nameof(CandidateDetails), new CandidateDetailsViewModel
        {
            Id = data.Candidate.Id,
            PlayName = data.Play.PlayName,
            PlaySlug = SlugHelper.Resolve(data.Play.Slug, data.Play.PlayName),
            CategoryCode = data.Candidate.AwardCategoryCode,
            CategoryName = data.CategoryName,
            Candidate = data.Candidate.Candidate,
            Role = data.Candidate.Role ?? "-",
            CurrentState = data.Candidate.IsCurrent ? "Yeni Aday" : "Eski Aday",
            Status = data.Candidate.IsActive ? "Aktif" : "Aktif Değil",
            CreatedAt = data.Candidate.CreatedAt,
            CreatedByName = data.Candidate.CreatedBy.HasValue &&
                auditUsers.TryGetValue(data.Candidate.CreatedBy.Value, out var creator)
                    ? creator
                    : null,
            UpdatedAt = data.Candidate.UpdatedAt,
            UpdatedByName = data.Candidate.UpdatedBy.HasValue &&
                auditUsers.TryGetValue(data.Candidate.UpdatedBy.Value, out var updater)
                    ? updater
                    : null,
            HasRoleAndPhoto = data.HasRoleAndPhoto,
            HasPhoto = hasPhoto
        });
    }

    [HttpGet("adaylar/{id:guid}/fotograf")]
    public async Task<IActionResult> CandidatePhoto(Guid id, CancellationToken cancellationToken)
    {
        var photo = await (
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join image in context.Images.AsNoTracking() on candidate.PhotoImageId equals image.Id
            where candidate.Id == id && candidate.IsPublished && image.IsPublished
            select new { image.ImageData, image.ContentType }
        ).SingleOrDefaultAsync(cancellationToken);

        return photo is null ? NotFound() : File(photo.ImageData, photo.ContentType);
    }
}
