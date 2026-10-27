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
    [HttpGet("diger-ayarlar/duyurular/{id:guid}")]
    public async Task<IActionResult> AnnouncementDetails(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Announcements.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished)
            .Select(item => new AnnouncementDetailsViewModel
            {
                Id = item.Id,
                AnnouncementLocationId = item.AnnouncementLocationId,
                Text = item.Text ?? string.Empty,
                ButtonText = item.ButtonText ?? string.Empty,
                ButtonLink = item.ButtonLink ?? string.Empty,
                BackgroundColor = item.BackgroundColor ?? string.Empty,
                HasImage = item.ImageId.HasValue && item.ImageAsset != null && item.ImageAsset.IsPublished,
                HasBackgroundImage = item.BackgroundImageId.HasValue &&
                    item.BackgroundImageAsset != null && item.BackgroundImageAsset.IsPublished
            })
            .SingleOrDefaultAsync(cancellationToken);

        return model is null ? NotFound() : View(model);
    }

    [HttpGet("diger-ayarlar/duyurular/{id:guid}/gorsel/{kind}")]
    public async Task<IActionResult> AnnouncementImage(
        Guid id,
        string kind,
        CancellationToken cancellationToken)
    {
        var imageId = await context.Announcements.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished)
            .Select(item => kind == "background" ? item.BackgroundImageId :
                kind == "content" ? item.ImageId : null)
            .SingleOrDefaultAsync(cancellationToken);
        if (!imageId.HasValue) return NotFound();

        var image = await context.Images.AsNoTracking()
            .Where(item => item.Id == imageId.Value && item.IsPublished)
            .Select(item => new { item.ImageData, item.ContentType })
            .SingleOrDefaultAsync(cancellationToken);
        return image is null ? NotFound() : File(image.ImageData, image.ContentType);
    }

    [HttpGet("diger-ayarlar/duyurular/{id:guid}/duzenle")]
    public async Task<IActionResult> EditAnnouncement(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Announcements.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished)
            .Select(item => new EditAnnouncementViewModel
            {
                Id = item.Id,
                AnnouncementLocationId = item.AnnouncementLocationId,
                Text = item.Text,
                ButtonText = item.ButtonText,
                ButtonLink = item.ButtonLink,
                BackgroundColor = item.BackgroundColor,
                HasExistingImage = item.ImageId.HasValue,
                HasExistingBackgroundImage = item.BackgroundImageId.HasValue
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (model is null) return NotFound();

        await PopulateAnnouncementImageStateAsync(model, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/duyurular/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditAnnouncement(
        Guid id,
        EditAnnouncementViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.Id != id) return BadRequest();

        var announcement = await context.Announcements.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (announcement is null) return NotFound();

        model.AnnouncementLocationId = announcement.AnnouncementLocationId;
        ModelState.Remove(nameof(model.AnnouncementLocationId));

        model.Text = NormalizeNullable(model.Text);
        model.ButtonText = NormalizeNullable(model.ButtonText);
        model.ButtonLink = NormalizeNullable(model.ButtonLink);
        model.BackgroundColor = NormalizeNullable(model.BackgroundColor)?.ToUpperInvariant();

        var contentImage = await ReadAnnouncementImageAsync(model.Image, "Görsel", cancellationToken);
        var backgroundImage = await ReadAnnouncementImageAsync(
            model.BackgroundImage, "Arka plan görseli", cancellationToken);
        if (contentImage.Error is not null)
            ModelState.AddModelError(nameof(model.Image), contentImage.Error);
        if (backgroundImage.Error is not null)
            ModelState.AddModelError(nameof(model.BackgroundImage), backgroundImage.Error);

        if (!ModelState.IsValid)
        {
            SetAnnouncementValidationPopup();
            await PopulateAnnouncementImageStateAsync(model, cancellationToken, announcement);
            return View(model);
        }

        var hasChanges = !string.Equals(announcement.Text, model.Text, StringComparison.Ordinal) ||
            !string.Equals(announcement.ButtonText, model.ButtonText, StringComparison.Ordinal) ||
            !string.Equals(announcement.ButtonLink, model.ButtonLink, StringComparison.Ordinal) ||
            !string.Equals(announcement.BackgroundColor, model.BackgroundColor, StringComparison.OrdinalIgnoreCase) ||
            model.Image is not null || model.BackgroundImage is not null ||
            (model.RemoveImage && announcement.ImageId.HasValue) ||
            (model.RemoveBackgroundImage && announcement.BackgroundImageId.HasValue);
        if (!hasChanges)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Herhangi bir değişiklik yapmadınız.";
            await PopulateAnnouncementImageStateAsync(model, cancellationToken, announcement);
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
            return Challenge();

        var oldImageId = announcement.ImageId;
        var oldBackgroundImageId = announcement.BackgroundImageId;
        var now = TurkeyTime.Now;

        announcement.Text = model.Text;
        announcement.ButtonText = model.ButtonText;
        announcement.ButtonLink = model.ButtonLink;
        announcement.BackgroundColor = model.BackgroundColor;
        announcement.UpdatedAt = now;
        announcement.UpdatedBy = currentUserId;

        if (contentImage.Data is not null)
            announcement.ImageId = AddAnnouncementImage(contentImage, currentUserId, now);
        else if (model.RemoveImage)
            announcement.ImageId = null;

        if (backgroundImage.Data is not null)
            announcement.BackgroundImageId = AddAnnouncementImage(backgroundImage, currentUserId, now);
        else if (model.RemoveBackgroundImage)
            announcement.BackgroundImageId = null;

        await SoftDeleteUnusedAnnouncementImageAsync(
            oldImageId, announcement, currentUserId, now, cancellationToken);
        if (oldBackgroundImageId != oldImageId)
        {
            await SoftDeleteUnusedAnnouncementImageAsync(
                oldBackgroundImageId, announcement, currentUserId, now, cancellationToken);
        }

        await context.SaveChangesAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Duyuru başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(AnnouncementDetails), new { id });
        return RedirectToAction(nameof(EditAnnouncement), new { id });
    }

    private Guid AddAnnouncementImage(
        AnnouncementImageUpload upload,
        Guid currentUserId,
        DateTime now)
    {
        var id = Guid.NewGuid();
        context.Images.Add(new Image
        {
            Id = id,
            FileName = upload.FileName!,
            ContentType = upload.ContentType!,
            ImageData = upload.Data!,
            CreatedAt = now,
            CreatedBy = currentUserId,
            IsPublished = true
        });
        return id;
    }

    private async Task SoftDeleteUnusedAnnouncementImageAsync(
        Guid? imageId,
        Announcement current,
        Guid currentUserId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (!imageId.HasValue || imageId == current.ImageId || imageId == current.BackgroundImageId)
            return;

        var isUsedElsewhere = await context.Announcements.AsNoTracking().AnyAsync(
                item => item.Id != current.Id && item.IsPublished &&
                    (item.ImageId == imageId || item.BackgroundImageId == imageId), cancellationToken) ||
            await context.Users.AsNoTracking().AnyAsync(
                item => item.IsPublished && item.PhotoImageId == imageId, cancellationToken) ||
            await context.PlayAwardCategories.AsNoTracking().AnyAsync(
                item => item.IsPublished && item.PhotoImageId == imageId, cancellationToken);
        if (isUsedElsewhere) return;

        var image = await context.Images.SingleOrDefaultAsync(
            item => item.Id == imageId.Value && item.IsPublished, cancellationToken);
        if (image is null) return;

        image.IsPublished = false;
        image.UpdatedAt = now;
        image.UpdatedBy = currentUserId;
    }

    private async Task PopulateAnnouncementImageStateAsync(
        EditAnnouncementViewModel model,
        CancellationToken cancellationToken,
        Announcement? trackedAnnouncement = null)
    {
        var imageIds = trackedAnnouncement is null
            ? await context.Announcements.AsNoTracking()
                .Where(item => item.Id == model.Id && item.IsPublished)
                .Select(item => new { item.ImageId, item.BackgroundImageId })
                .SingleAsync(cancellationToken)
            : new { trackedAnnouncement.ImageId, trackedAnnouncement.BackgroundImageId };

        var ids = new[] { imageIds.ImageId, imageIds.BackgroundImageId }
            .Where(value => value.HasValue).Select(value => value!.Value).Distinct().ToArray();
        var files = await context.Images.AsNoTracking()
            .Where(item => ids.Contains(item.Id) && item.IsPublished)
            .Select(item => new { item.Id, item.FileName })
            .ToDictionaryAsync(item => item.Id, item => item.FileName, cancellationToken);

        string? imageName = null;
        model.HasExistingImage = imageIds.ImageId.HasValue &&
            files.TryGetValue(imageIds.ImageId.Value, out imageName) && !model.RemoveImage;
        model.ExistingImageFileName = model.HasExistingImage ? imageName! : string.Empty;
        model.ExistingImageUrl = model.HasExistingImage
            ? Url.Action(nameof(AnnouncementImage), new { id = model.Id, kind = "content" }) ?? string.Empty
            : string.Empty;

        string? backgroundName = null;
        model.HasExistingBackgroundImage = imageIds.BackgroundImageId.HasValue &&
            files.TryGetValue(imageIds.BackgroundImageId.Value, out backgroundName) &&
            !model.RemoveBackgroundImage;
        model.ExistingBackgroundImageFileName = model.HasExistingBackgroundImage
            ? backgroundName! : string.Empty;
        model.ExistingBackgroundImageUrl = model.HasExistingBackgroundImage
            ? Url.Action(nameof(AnnouncementImage), new { id = model.Id, kind = "background" }) ?? string.Empty
            : string.Empty;
    }

    private async Task<AnnouncementImageUpload> ReadAnnouncementImageAsync(
        IFormFile? file,
        string fieldName,
        CancellationToken cancellationToken)
    {
        if (file is null) return new(null, null, null, null);
        if (file.Length == 0 || file.Length > ImageUploadPolicy.MaximumFileSizeBytes)
            return new(null, null, null,
                $"{fieldName}: {ImageUploadPolicy.MaximumFileSizeMessage}");

        await using var stream = new MemoryStream();
        await file.CopyToAsync(stream, cancellationToken);
        var data = stream.ToArray();
        if (!ImageUploadFormat.TryNormalize(data, file.FileName, out var contentType, out var fileName))
            return new(null, null, null, $"{fieldName} yalnızca JPG, PNG veya WEBP olabilir.");

        return new(data, contentType, fileName, null);
    }

    private void SetAnnouncementValidationPopup()
    {
        var message = string.Join("\n", ModelState.Values
            .SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage)
            .Where(error => !string.IsNullOrWhiteSpace(error))
            .Distinct());
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = string.IsNullOrWhiteSpace(message)
            ? "Duyuru alanlarını kontrol ediniz."
            : message;
    }

    private static string? NormalizeNullable(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private sealed record AnnouncementImageUpload(
        byte[]? Data,
        string? ContentType,
        string? FileName,
        string? Error);
}
