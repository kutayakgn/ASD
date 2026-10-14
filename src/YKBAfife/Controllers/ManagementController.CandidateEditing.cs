using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    [HttpGet("adaylar/{id:guid}/duzenle")]
    public async Task<IActionResult> EditCandidate(Guid id, CancellationToken cancellationToken)
    {
        var model = await BuildEditCandidateViewModelAsync(id, cancellationToken);
        return model is null ? NotFound() : View(model);
    }

    [AdminMutationAudit]
    [HttpPost("adaylar/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditCandidate(
        Guid id,
        EditCandidateViewModel model,
        CancellationToken cancellationToken)
    {
        if (id != model.Id) return BadRequest();

        var data = await (
            from candidate in context.PlayAwardCategories
            join play in context.Plays on candidate.PlayId equals play.Id
            join category in context.AwardCategories on candidate.AwardCategoryCode equals category.CategoryCode
            where candidate.Id == id && candidate.IsPublished && play.IsPublished && category.IsPublished
            select new { Candidate = candidate, Play = play, Category = category }
        ).SingleOrDefaultAsync(cancellationToken);
        if (data is null) return NotFound();
        if (CandidateCategoryPolicy.IsSystemManaged(data.Candidate.AwardCategoryCode)) return BadRequest();
        var supportsRoleAndPhoto =
            CandidateCategoryPolicy.SupportsRoleAndPhoto(data.Candidate.AwardCategoryCode);

        model.Candidate = model.Candidate?.Trim() ?? string.Empty;
        model.Role = string.IsNullOrWhiteSpace(model.Role) ? null : model.Role.Trim();
        if (!supportsRoleAndPhoto) model.Role = null;
        if (model.Candidate.Length is < 2 or > 250)
            return await EditCandidateFailureAsync(id, "Adı Soyadı alanı 2 ile 250 karakter arasında olmalıdır.", cancellationToken);
        if (!model.IsActive.HasValue)
            return await EditCandidateFailureAsync(id, "Statü seçimi zorunludur.", cancellationToken);
        if (supportsRoleAndPhoto && string.IsNullOrWhiteSpace(model.Role))
            return await EditCandidateFailureAsync(id, "Rol Adı alanı zorunludur.", cancellationToken);
        if (model.Role?.Length > 200)
            return await EditCandidateFailureAsync(id, "Rol Adı en fazla 200 karakter olabilir.", cancellationToken);
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
            return Challenge();

        if (!supportsRoleAndPhoto && (model.Photo is not null || model.RemovePhoto))
            return await EditCandidateFailureAsync(
                id, "Bu ödül kategorisinde rol veya fotoğraf düzenlenemez.", cancellationToken);

        var photoResult = supportsRoleAndPhoto
            ? await ReadCandidatePhotoAsync(model.Photo, cancellationToken)
            : (null, null, null, null);
        if (photoResult.Error is not null)
            return await EditCandidateFailureAsync(id, photoResult.Error, cancellationToken);

        await using var transaction = await context.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
        try
        {
            var candidates = await context.PlayAwardCategories
                .Where(item => item.PlayId == data.Play.Id && item.IsPublished)
                .ToListAsync(cancellationToken);
            var candidate = candidates.Single(item => item.Id == id);
            var roleChanged = supportsRoleAndPhoto &&
                !string.Equals(candidate.Role?.Trim(), model.Role, StringComparison.Ordinal);
            var roleGroup = candidates.Where(item =>
                item.AwardCategoryCode == candidate.AwardCategoryCode &&
                item.RoleCode == candidate.RoleCode).ToArray();

            if (supportsRoleAndPhoto)
            {
                if (roleChanged && roleGroup.Length > 1 && !model.ConfirmRoleGroupUpdate)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return await EditCandidateFailureAsync(
                        id,
                        "Rol grubundaki diğer adaylar onay verilmeden güncellenemez.",
                        cancellationToken);
                }
            }

            var now = TurkeyTime.Now;
            candidate.Candidate = model.Candidate;
            candidate.IsActive = model.IsActive.Value;
            candidate.UpdatedAt = now;
            candidate.UpdatedBy = currentUserId;
            if (roleChanged)
            {
                // The role integrity trigger evaluates each SQL statement. Update the whole
                // logical role group atomically so no temporary mixed-role state is visible.
                await context.PlayAwardCategories
                    .Where(item =>
                        item.PlayId == candidate.PlayId &&
                        item.AwardCategoryCode == candidate.AwardCategoryCode &&
                        item.RoleCode == candidate.RoleCode &&
                        item.IsPublished)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(item => item.Role, model.Role)
                        .SetProperty(item => item.UpdatedAt, now)
                        .SetProperty(item => item.UpdatedBy, currentUserId),
                        cancellationToken);
            }

            var oldPhotoId = candidate.PhotoImageId;
            if (photoResult.Data is not null)
            {
                var newPhotoId = Guid.NewGuid();
                context.Images.Add(new Image
                {
                    Id = newPhotoId,
                    FileName = photoResult.FileName!,
                    ContentType = photoResult.ContentType!,
                    ImageData = photoResult.Data,
                    CreatedAt = now,
                    CreatedBy = currentUserId,
                    IsPublished = true
                });
                candidate.PhotoImageId = newPhotoId;
            }
            else if (model.RemovePhoto)
            {
                candidate.PhotoImageId = null;
            }

            if (oldPhotoId.HasValue && oldPhotoId != candidate.PhotoImageId)
            {
                var oldPhoto = await context.Images.SingleOrDefaultAsync(
                    image => image.Id == oldPhotoId.Value && image.IsPublished,
                    cancellationToken);
                if (oldPhoto is not null)
                {
                    oldPhoto.IsPublished = false;
                    oldPhoto.UpdatedAt = now;
                    oldPhoto.UpdatedBy = currentUserId;
                }
            }

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogError(exception, "Aday güncellenemedi. CandidateId: {CandidateId}", id);
            return await EditCandidateFailureAsync(
                id,
                "Aday güncellenemedi. Bilgileri kontrol ederek tekrar deneyiniz.",
                cancellationToken);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Aday başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(CandidateDetails), new { id });
        return RedirectToAction(nameof(EditCandidate), new { id });
    }

    private async Task<EditCandidateViewModel?> BuildEditCandidateViewModelAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        var data = await (
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join play in context.Plays.AsNoTracking() on candidate.PlayId equals play.Id
            join category in context.AwardCategories.AsNoTracking()
                on candidate.AwardCategoryCode equals category.CategoryCode
            where candidate.Id == id && candidate.IsPublished &&
                  candidate.AwardCategoryCode != CandidateCategoryPolicy.BestPlayCategoryCode &&
                  candidate.AwardCategoryCode != CandidateCategoryPolicy.BestDirectorCategoryCode &&
                  play.IsPublished && category.IsPublished
            select new { Candidate = candidate, Play = play, Category = category }
        ).SingleOrDefaultAsync(cancellationToken);
        if (data is null) return null;

        var candidates = await context.PlayAwardCategories.AsNoTracking()
            .Where(item => item.PlayId == data.Play.Id && item.IsPublished)
            .Select(item => new { item.Id, item.Candidate, item.Role, item.RoleCode, item.AwardCategoryCode })
            .ToArrayAsync(cancellationToken);
        var comparer = StringComparer.Create(new System.Globalization.CultureInfo("tr-TR"), true);
        var relatedCandidates = candidates
            .Where(item => item.Id != id &&
                item.AwardCategoryCode == data.Candidate.AwardCategoryCode &&
                item.RoleCode == data.Candidate.RoleCode)
            .Select(item => new RelatedCandidateViewModel
            {
                Id = item.Id,
                Name = item.Candidate,
                Url = Url.Action(nameof(CandidateDetails), new { id = item.Id }) ?? $"/adaylar/{item.Id:D}"
            }).ToArray();
        var otherRoleNames = candidates
            .Where(item => item.AwardCategoryCode != data.Candidate.AwardCategoryCode ||
                           item.RoleCode != data.Candidate.RoleCode)
            .Select(item => item.Role)
            .Where(role => !string.IsNullOrWhiteSpace(role))
            .Select(role => role!)
            .Distinct(comparer)
            .ToArray();

        var model = new EditCandidateViewModel
        {
            Id = data.Candidate.Id,
            PlayName = data.Play.PlayName,
            PlaySlug = SlugHelper.Resolve(data.Play.Slug, data.Play.PlayName),
            CategoryName = data.Category.CategoryName,
            Candidate = data.Candidate.Candidate,
            Role = data.Candidate.Role,
            OriginalRole = data.Candidate.Role ?? string.Empty,
            IsActive = data.Candidate.IsActive,
            HasRoleAndPhoto = CandidateCategoryPolicy.SupportsRoleAndPhoto(
                data.Candidate.AwardCategoryCode),
            HasExistingPhoto = data.Candidate.PhotoImageId.HasValue,
            ExistingPhotoUrl = data.Candidate.PhotoImageId.HasValue
                ? Url.Action(nameof(CandidatePhoto), new { id = data.Candidate.Id }) ?? string.Empty
                : string.Empty,
            RelatedCandidates = relatedCandidates,
            OtherRoleNames = otherRoleNames
        };

        if (data.Candidate.PhotoImageId.HasValue)
        {
            model.ExistingPhotoFileName = await context.Images.AsNoTracking()
                .Where(image => image.Id == data.Candidate.PhotoImageId.Value && image.IsPublished)
                .Select(image => image.FileName)
                .SingleOrDefaultAsync(cancellationToken) ?? string.Empty;
            model.HasExistingPhoto = !string.IsNullOrWhiteSpace(model.ExistingPhotoFileName);
            if (!model.HasExistingPhoto) model.ExistingPhotoUrl = string.Empty;
        }

        return model;
    }

    private async Task<IActionResult> EditCandidateFailureAsync(
        Guid id,
        string message,
        CancellationToken cancellationToken)
    {
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = message;
        var model = await BuildEditCandidateViewModelAsync(id, cancellationToken);
        return model is null ? NotFound() : View(nameof(EditCandidate), model);
    }

    private async Task<(byte[]? Data, string? ContentType, string? FileName, string? Error)>
        ReadCandidatePhotoAsync(IFormFile? photo, CancellationToken cancellationToken)
    {
        if (photo is null) return (null, null, null, null);
        if (photo.Length == 0 || photo.Length > ImageUploadPolicy.MaximumFileSizeBytes)
            return (null, null, null, ImageUploadPolicy.MaximumFileSizeMessage);

        await using var photoStream = new MemoryStream();
        await photo.CopyToAsync(photoStream, cancellationToken);
        var data = photoStream.ToArray();
        var contentType = photo.ContentType.Trim().ToLowerInvariant();
        if (!IsSupportedPhoto(data, contentType, Path.GetFileName(photo.FileName)))
            return (null, null, null, "Yalnızca JPEG, PNG veya WebP formatında fotoğraf yükleyebilirsiniz.");

        return (data, contentType, Path.GetFileName(photo.FileName), null);
    }
}
