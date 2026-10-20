using System.Data;
using System.Buffers.Binary;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Exports;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController(
    AfifeContext context,
    IJuryReportService juryReportService,
    IArchiveComparisonReportService archiveComparisonReportService,
    ISeasonSettingsReportService seasonSettingsReportService,
    IAdditionalVotingReportService additionalVotingReportService,
    ITicketSalesReportService ticketSalesReportService,
    IBlacklistReportService blacklistReportService,
    IApplicationReportService applicationReportService,
    IJuryWatchedPlayReportService juryWatchedPlayReportService,
    IPlayReportService playReportService,
    ICandidateReportService candidateReportService,
    IRankingReportService rankingReportService,
    IUserActivityLogger activityLogger,
    IExcelExporter excelExporter,
    ILogger<ManagementController> logger) : Controller
{
    [HttpGet("sanata-sozumuz")]
    public IActionResult ArtPromise() => Page(
        "Sanata Sözümüz",
        "Afife'nin sanata verdiği sözü ve içeriklerini bu alandan yönetin.");
    [HttpGet("juriler")]
    public async Task<IActionResult> Juries(CancellationToken cancellationToken)
    {
        var report = await juryReportService.GetPageAsync(new JuryTableQuery(), cancellationToken);
        return View(new JuryDashboardViewModel
        {
            JuryTable = JuryComplexTableFactory.Create(report)
        });
    }

    [HttpPost("juriler/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> JuryTable(
        [FromForm] JuryTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await juryReportService.GetPageAsync(query, cancellationToken);
        var model = JuryComplexTableFactory.Create(report);
        return ViewComponent("ComplexTable", new { model });
    }
    [HttpGet("juriler/{id:guid}")]
    public async Task<IActionResult> JuryDetails(Guid id, CancellationToken cancellationToken)
    {
        var jury = await context.Users
            .AsNoTracking()
            .Where(user => user.Id == id && user.IsPublished && user.RoleCode == 2)
            .Select(user => new
            {
                user.Id,
                user.Username,
                user.Email,
                user.FirstName,
                user.LastName,
                user.Phone,
                user.PhotoImageId,
                user.IsActive,
                user.IsJuryPresident,
                user.CreatedAt,
                user.CreatedBy,
                user.UpdatedAt,
                user.UpdatedBy
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (jury is null)
        {
            return NotFound();
        }

        var metrics = await context.UserLogs
            .AsNoTracking()
            .Where(log => log.UserId == id && log.IsPublished)
            .GroupBy(_ => 1)
            .Select(logs => new
            {
                LastLoginAt = logs
                    .Where(log => log.EventType == UserActivityTypes.LoginSucceeded && log.IsSuccessful)
                    .Max(log => (DateTime?)log.OccurredAt),
                LastPasswordChangeAt = logs
                    .Where(log => log.EventType == UserActivityTypes.PasswordChanged && log.IsSuccessful)
                    .Max(log => (DateTime?)log.OccurredAt),
                SuccessfulLoginCount = logs.Count(log =>
                    log.EventType == UserActivityTypes.LoginSucceeded && log.IsSuccessful),
                FailedLoginCount = logs.Count(log =>
                    log.EventType == UserActivityTypes.LoginFailed && !log.IsSuccessful)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var auditUserIds = new[] { jury.CreatedBy, jury.UpdatedBy }
            .Where(userId => userId.HasValue)
            .Select(userId => userId!.Value)
            .Distinct()
            .ToArray();
        var auditUsers = await context.Users
            .AsNoTracking()
            .Where(user => auditUserIds.Contains(user.Id))
            .Select(user => new
            {
                user.Id,
                FullName = (user.FirstName + " " + user.LastName).Trim()
            })
            .ToDictionaryAsync(user => user.Id, user => user.FullName, cancellationToken);

        var watchedPlayReport = await juryWatchedPlayReportService.GetPageAsync(
            new JuryWatchedPlayTableQuery { JuryId = id },
            cancellationToken);
        return View(new JuryDetailsViewModel
        {
            Id = jury.Id,
            WatchedPlaysTable = JuryWatchedPlayComplexTableFactory.Create(watchedPlayReport),
            Username = jury.Username,
            Email = jury.Email,
            FullName = (jury.FirstName + " " + jury.LastName).Trim(),
            Phone = jury.Phone ?? "-",
            HasPhoto = jury.PhotoImageId.HasValue,
            IsActive = jury.IsActive,
            IsJuryPresident = jury.IsJuryPresident,
            LastLoginAt = metrics?.LastLoginAt,
            LastPasswordChangeAt = metrics?.LastPasswordChangeAt,
            SuccessfulLoginCount = metrics?.SuccessfulLoginCount ?? 0,
            FailedLoginCount = metrics?.FailedLoginCount ?? 0,
            CreatedAt = jury.CreatedAt,
            CreatedByName = jury.CreatedBy.HasValue && auditUsers.TryGetValue(jury.CreatedBy.Value, out var creator)
                ? creator
                : null,
            UpdatedAt = jury.UpdatedAt,
            UpdatedByName = jury.UpdatedBy.HasValue && auditUsers.TryGetValue(jury.UpdatedBy.Value, out var updater)
                ? updater
                : null
        });
    }

    [HttpPost("juriler/izlenen-oyunlar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> JuryWatchedPlaysTable(
        [FromForm] JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await juryWatchedPlayReportService.GetPageAsync(query, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.JuryName))
        {
            return NotFound();
        }

        return ViewComponent("ComplexTable", new
        {
            model = JuryWatchedPlayComplexTableFactory.Create(report)
        });
    }

    [HttpPost("juriler/izlenen-oyunlar/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportJuryWatchedPlays(
        [FromForm] JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await juryWatchedPlayReportService.GetExportAsync(query, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.JuryName))
        {
            return NotFound();
        }

        var document = JuryWatchedPlayExcelExportFactory.Create(report, query);
        var content = excelExporter.Export(document);
        var fileName = $"juri-izlenmeleri-{DateTime.Now:yyyyMMdd-HHmm}.xlsx";
        return File(
            content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            fileName);
    }
    [HttpGet("juriler/{id:guid}/fotograf")]
    public async Task<IActionResult> JuryPhoto(Guid id, CancellationToken cancellationToken)
    {
        var photo = await (
            from user in context.Users.AsNoTracking()
            join image in context.Images.AsNoTracking()
                on user.PhotoImageId equals (Guid?)image.Id
            where user.Id == id && user.IsPublished && user.RoleCode == 2 && image.IsPublished
            select new { image.ImageData, image.ContentType }).SingleOrDefaultAsync(cancellationToken);

        return photo is null
            ? NotFound()
            : File(photo.ImageData, photo.ContentType);
    }

    [AdminMutationAudit]
    [HttpPost("juriler/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteJury(Guid id, CancellationToken cancellationToken)
    {
        var jury = await context.Users.SingleOrDefaultAsync(
            user => user.Id == id && user.IsPublished && user.RoleCode == 2,
            cancellationToken);
        if (jury is null)
        {
            return NotFound();
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        jury.IsPublished = false;
        jury.IsActive = false;
        jury.IsJuryPresident = false;
        jury.UpdatedAt = TurkeyTime.Now;
        jury.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Jüri başarıyla silindi.";
        return RedirectToAction(nameof(Juries));
    }

    [HttpGet("juriler/{id:guid}/duzenle")]
    public async Task<IActionResult> EditJury(Guid id, CancellationToken cancellationToken)
    {
        var jury = await context.Users
            .AsNoTracking()
            .Where(user => user.Id == id && user.IsPublished && user.RoleCode == 2)
            .Select(user => new EditJuryViewModel
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                FullName = (user.FirstName + " " + user.LastName).Trim(),
                Phone = user.Phone ?? string.Empty,
                IsActive = user.IsActive,
                IsJuryPresident = user.IsJuryPresident
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (jury is null)
        {
            return NotFound();
        }

        var photoId = await context.Users
            .AsNoTracking()
            .Where(user => user.Id == id)
            .Select(user => user.PhotoImageId)
            .SingleAsync(cancellationToken);
        await PopulateEditJuryPhotoStateAsync(jury, photoId, cancellationToken);
        return View(jury);
    }

    [AdminMutationAudit]
    [HttpPost("juriler/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditJury(
        Guid id,
        EditJuryViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.Id != Guid.Empty && model.Id != id)
        {
            return BadRequest();
        }

        var jury = await context.Users.SingleOrDefaultAsync(
            user => user.Id == id && user.IsPublished && user.RoleCode == 2,
            cancellationToken);
        if (jury is null)
        {
            return NotFound();
        }

        model.Id = id;
        model.Username = model.Username?.Trim() ?? string.Empty;
        model.Email = model.Email?.Trim() ?? string.Empty;
        model.Password ??= string.Empty;
        model.FullName = string.Join(
            ' ',
            (model.FullName ?? string.Empty).Split(
                (char[]?)null,
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        model.Phone = model.Phone?.Trim() ?? string.Empty;

        ModelState.Clear();
        TryValidateModel(model);

        if (model.IsJuryPresident && model.IsActive != true)
        {
            ModelState.AddModelError(
                nameof(model.IsJuryPresident),
                "Jüri Başkanı yalnızca güncel bir jüri olabilir.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Id != id &&
                        user.IsPublished &&
                        user.RoleCode == 2 &&
                        user.Username == model.Username,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Username), "Bu kullanıcı adı zaten kullanılıyor.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Id != id &&
                        user.IsPublished &&
                        user.RoleCode == 2 &&
                        user.Email == model.Email,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Email), "Bu e-posta adresi zaten kullanılıyor.");
        }

        byte[]? photoData = null;
        string? photoContentType = null;
        string? photoFileName = null;
        if (model.Photo is not null)
        {
            if (model.Photo.Length == 0 ||
                model.Photo.Length > ImageUploadPolicy.MaximumFileSizeBytes)
            {
                ModelState.AddModelError(
                    nameof(model.Photo), ImageUploadPolicy.MaximumFileSizeMessage);
            }
            else
            {
                await using var photoStream = new MemoryStream();
                await model.Photo.CopyToAsync(photoStream, cancellationToken);
                photoData = photoStream.ToArray();
                photoContentType = model.Photo.ContentType.Trim().ToLowerInvariant();
                photoFileName = Path.GetFileName(model.Photo.FileName);
                if (!IsSupportedPhoto(photoData, photoContentType, photoFileName))
                {
                    ModelState.AddModelError(
                        nameof(model.Photo),
                        "Yalnızca JPEG, PNG veya WebP formatında fotoğraf yükleyebilirsiniz.");
                }
            }
        }

        if (!ModelState.IsValid)
        {
            await PopulateEditJuryPhotoStateAsync(model, jury.PhotoImageId, cancellationToken);
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);

        var oldEmail = jury.Email;
        var passwordChanged = model.Password is not null;
        var fullNameParts = model.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        jury.FirstName = string.Join(' ', fullNameParts[..^1]);
        jury.LastName = fullNameParts[^1];
        jury.Username = model.Username;
        jury.Email = model.Email;
        jury.Phone = model.Phone;
        jury.IsActive = model.IsActive!.Value;
        jury.IsJuryPresident = model.IsJuryPresident;
        jury.UpdatedAt = TurkeyTime.Now;
        jury.UpdatedBy = currentUserId;
        if (passwordChanged)
        {
            jury.PasswordHash = PasswordHashHelper.HashPassword(model.Password!);
        }

        var oldPhotoId = jury.PhotoImageId;
        if (photoData is not null && photoContentType is not null && photoFileName is not null)
        {
            var newPhotoId = Guid.NewGuid();
            context.Images.Add(new Image
            {
                Id = newPhotoId,
                FileName = photoFileName,
                ContentType = photoContentType,
                ImageData = photoData,
                CreatedAt = TurkeyTime.Now,
                CreatedBy = currentUserId,
                IsPublished = true
            });
            jury.PhotoImageId = newPhotoId;
        }
        else if (model.RemovePhoto)
        {
            jury.PhotoImageId = null;
        }

        if (oldPhotoId.HasValue && oldPhotoId != jury.PhotoImageId)
        {
            var oldPhoto = await context.Images.SingleOrDefaultAsync(
                image => image.Id == oldPhotoId.Value && image.IsPublished,
                cancellationToken);
            if (oldPhoto is not null)
            {
                oldPhoto.IsPublished = false;
                oldPhoto.UpdatedAt = TurkeyTime.Now;
                oldPhoto.UpdatedBy = currentUserId;
            }
        }

        if (model.IsJuryPresident)
        {
            await ClearOtherJuryPresidentAsync(jury.Id, currentUserId, cancellationToken);
        }

        await context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);


        if (!string.Equals(oldEmail, jury.Email, StringComparison.OrdinalIgnoreCase))
        {
            await activityLogger.LogAsync(
                UserActivityTypes.EmailChanged,
                true,
                jury.Id,
                jury.Username,
                currentUserId,
                details: "Jüri e-posta adresi güncellendi.",
                oldValue: oldEmail,
                newValue: jury.Email,
                cancellationToken: cancellationToken);
        }

        if (passwordChanged)
        {
            await activityLogger.LogAsync(
                UserActivityTypes.PasswordChanged,
                true,
                jury.Id,
                jury.Username,
                currentUserId,
                details: "Jüri şifresi yönetici tarafından değiştirildi.",
                cancellationToken: cancellationToken);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Değişiklikler başarıyla kaydedildi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(JuryDetails), new { id }) ?? $"/juriler/{id}";
        return RedirectToAction(nameof(EditJury), new { id });
    }
    [HttpGet("juri-ekle")]
    public IActionResult AddJury() => View(new AddJuryViewModel());

    [AdminMutationAudit]
    [HttpPost("juri-ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddJury(
        AddJuryViewModel model,
        CancellationToken cancellationToken)
    {
        model.Username = model.Username?.Trim() ?? string.Empty;
        model.Email = model.Email?.Trim() ?? string.Empty;
        model.FullName = string.Join(
            ' ',
            (model.FullName ?? string.Empty).Split(
                (char[]?)null,
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        model.Phone = model.Phone?.Trim() ?? string.Empty;

        ModelState.Clear();
        TryValidateModel(model);

        if (model.IsJuryPresident && model.IsActive != true)
        {
            ModelState.AddModelError(
                nameof(model.IsJuryPresident),
                "Jüri Başkanı yalnızca güncel bir jüri olabilir.");
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.IsPublished &&
                        user.RoleCode == 2 &&
                        user.Username == model.Username,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Username), "Bu kullanıcı adı zaten kullanılıyor.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.IsPublished &&
                        user.RoleCode == 2 &&
                        user.Email == model.Email,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Email), "Bu e-posta adresi zaten kullanılıyor.");
        }

        byte[]? photoData = null;
        string? photoContentType = null;
        string? photoFileName = null;

        if (model.Photo is not null)
        {
            if (model.Photo.Length == 0 ||
                model.Photo.Length > ImageUploadPolicy.MaximumFileSizeBytes)
            {
                ModelState.AddModelError(
                    nameof(model.Photo), ImageUploadPolicy.MaximumFileSizeMessage);
            }
            else
            {
                await using var photoStream = new MemoryStream();
                await model.Photo.CopyToAsync(photoStream, cancellationToken);
                photoData = photoStream.ToArray();
                photoContentType = model.Photo.ContentType.Trim().ToLowerInvariant();
                photoFileName = Path.GetFileName(model.Photo.FileName);

                if (!IsSupportedPhoto(photoData, photoContentType, photoFileName))
                {
                    ModelState.AddModelError(
                        nameof(model.Photo),
                        "Yalnızca JPEG, PNG veya WebP formatında fotoğraf yükleyebilirsiniz.");
                }
            }
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);

        var fullNameParts = model.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var lastName = fullNameParts[^1];
        var firstName = string.Join(' ', fullNameParts[..^1]);
        var now = TurkeyTime.Now;
        Guid? photoId = null;

        if (photoData is not null && photoContentType is not null && photoFileName is not null)
        {
            photoId = Guid.NewGuid();
            context.Images.Add(new Image
            {
                Id = photoId.Value,
                FileName = photoFileName,
                ContentType = photoContentType,
                ImageData = photoData,
                CreatedAt = now,
                CreatedBy = currentUserId,
                IsPublished = true
            });
        }

        var juryId = Guid.NewGuid();
        context.Users.Add(new Models.Entities.User
        {
            Id = juryId,
            FirstName = firstName,
            LastName = lastName,
            Phone = model.Phone,
            PhotoImageId = photoId,
            Username = model.Username,
            PasswordHash = PasswordHashHelper.HashPassword(model.Password),
            Email = model.Email,
            CreatedAt = now,
            CreatedBy = currentUserId,
            IsPublished = true,
            IsActive = model.IsActive!.Value,
            IsJuryPresident = model.IsJuryPresident,
            RoleCode = 2
        });

        if (model.IsJuryPresident)
        {
            await ClearOtherJuryPresidentAsync(juryId, currentUserId, cancellationToken);
        }

        await context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);


        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Jüri başarıyla kaydedildi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Juries)) ?? "/juriler";
        return RedirectToAction(nameof(AddJury));
    }

    private async Task PopulateEditJuryPhotoStateAsync(
        EditJuryViewModel model,
        Guid? photoImageId,
        CancellationToken cancellationToken)
    {
        model.HasExistingPhoto = false;
        model.ExistingPhotoFileName = string.Empty;
        model.ExistingPhotoUrl = string.Empty;
        if (!photoImageId.HasValue || model.RemovePhoto)
        {
            return;
        }

        var fileName = await context.Images
            .AsNoTracking()
            .Where(image => image.Id == photoImageId.Value && image.IsPublished)
            .Select(image => image.FileName)
            .SingleOrDefaultAsync(cancellationToken);
        if (fileName is null)
        {
            return;
        }

        model.HasExistingPhoto = true;
        model.ExistingPhotoFileName = fileName;
        model.ExistingPhotoUrl = Url.Action(nameof(JuryPhoto), new { id = model.Id }) ?? string.Empty;
    }

    private Task ClearOtherJuryPresidentAsync(
        Guid selectedJuryId,
        Guid currentUserId,
        CancellationToken cancellationToken) =>
        context.Users
            .Where(user =>
                user.Id != selectedJuryId &&
                user.IsPublished &&
                user.RoleCode == 2 &&
                user.IsJuryPresident)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(user => user.IsJuryPresident, false)
                .SetProperty(user => user.UpdatedAt, TurkeyTime.Now)
                .SetProperty(user => user.UpdatedBy, currentUserId), cancellationToken);
    private static bool IsSupportedPhoto(
        byte[] data,
        string contentType,
        string? fileName)
    {
        var extension = Path.GetExtension(fileName ?? string.Empty).ToLowerInvariant();

        if (contentType == "image/jpeg")
        {
            return extension is ".jpg" or ".jpeg" &&
                   data.Length >= 4 &&
                   data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF &&
                   data[^2] == 0xFF && data[^1] == 0xD9;
        }

        if (contentType == "image/png")
        {
            byte[] signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
            byte[] ending = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
            return extension == ".png" &&
                   data.Length >= 33 &&
                   data.AsSpan(0, signature.Length).SequenceEqual(signature) &&
                   data.AsSpan(12, 4).SequenceEqual("IHDR"u8) &&
                   data.AsSpan(data.Length - ending.Length).SequenceEqual(ending);
        }

        if (contentType != "image/webp" || extension != ".webp" || data.Length < 16 ||
            !data.AsSpan(0, 4).SequenceEqual("RIFF"u8) ||
            !data.AsSpan(8, 4).SequenceEqual("WEBP"u8))
        {
            return false;
        }

        var chunk = data.AsSpan(12, 4);
        return (chunk.SequenceEqual("VP8 "u8) ||
                chunk.SequenceEqual("VP8L"u8) ||
                chunk.SequenceEqual("VP8X"u8)) &&
               BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(4, 4)) ==
               (uint)(data.Length - 8);
    }



    [HttpGet("oyunlar")]
    public async Task<IActionResult> Plays(CancellationToken cancellationToken)
    {
        var report = await playReportService.GetPageAsync(new PlayTableQuery(), cancellationToken);
        return View(new PlaysDashboardViewModel
        {
            PlaysTable = PlayComplexTableFactory.Create(report),
            JuryVotingStatus = report.JuryVotingStatus,
            KunyeGirisStatus = report.KunyeGirisStatus,
            RecordType = report.RecordType
        });
    }

    [HttpPost("oyunlar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> PlaysTable(
        [FromForm] PlayTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await playReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = PlayComplexTableFactory.Create(report) });
    }

    [AdminMutationAudit]
    [HttpPost("oyunlar/{id:guid}/juri-oylama-status")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateJuryVotingStatus(
        Guid id,
        [FromForm] bool isActive,
        CancellationToken cancellationToken) =>
        UpdatePlayStatus(id, isActive, true, cancellationToken);

    [AdminMutationAudit]
    [HttpPost("oyunlar/{id:guid}/kunye-giris-status")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateKunyeGirisStatus(
        Guid id,
        [FromForm] bool isActive,
        CancellationToken cancellationToken) =>
        UpdatePlayStatus(id, isActive, false, cancellationToken);

    [HttpGet("oyunlar/ekle")]
    public async Task<IActionResult> AddPlay(CancellationToken cancellationToken)
    {
        var model = new AddPlayViewModel();
        await PopulateAddPlayOptionsAsync(model, cancellationToken);
        return View(model);
    }

    [HttpPost("oyunlar/benzerlik-kontrolu")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CheckPlaySimilarity(
        [FromForm] string playName,
        [FromForm] string theaterName,
        [FromForm] Guid? playId,
        CancellationToken cancellationToken)
    {
        playName = playName?.Trim() ?? string.Empty;
        theaterName = theaterName?.Trim() ?? string.Empty;
        if (playName.Length < 2 || theaterName.Length < 2)
        {
            return BadRequest(new { message = "Benzerlik kontrolü için geçerli oyun ve tiyatro adı giriniz." });
        }

        var result = await GetAddPlaySimilarityAsync(playName, theaterName, cancellationToken, playId);
        if (result.HasExactMatch)
        {
            return Json(new
            {
                status = "exact",
                message = "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin."
            });
        }

        return Json(new
        {
            status = result.SimilarPlays.Count > 0 ? "similar" : "none",
            matches = result.SimilarPlays.Select(play => new
            {
                name = play.PlayName,
                url = Url.Action(
                    nameof(PlayDetails),
                    new { slug = SlugHelper.Resolve(play.Slug, play.PlayName) })
                    ?? $"/oyunlar/{Uri.EscapeDataString(SlugHelper.Resolve(play.Slug, play.PlayName))}"
            })
        });
    }

    [AdminMutationAudit]
    [HttpPost("oyunlar/ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddPlay(
        AddPlayViewModel model,
        CancellationToken cancellationToken)
    {
        model.PlayName = model.PlayName?.Trim() ?? string.Empty;
        model.TheaterName = model.TheaterName?.Trim() ?? string.Empty;
        model.SelectedJuryIds = model.SelectedJuryIds?.Distinct().ToList() ?? [];

        if (model.PlayName.Length > AddPlayViewModel.NameMaxLength)
        {
            ModelState.AddModelError(
                nameof(model.PlayName),
                $"Oyun adı en fazla {AddPlayViewModel.NameMaxLength} karakter olmalıdır.");
        }

        if (model.TheaterName.Length > AddPlayViewModel.NameMaxLength)
        {
            ModelState.AddModelError(
                nameof(model.TheaterName),
                $"Tiyatro adı en fazla {AddPlayViewModel.NameMaxLength} karakter olmalıdır.");
        }

        if (!model.StatusCode.HasValue || !await context.PlayStatuses.AsNoTracking().AnyAsync(
                status => status.IsPublished && status.StatusCode != 1 && status.StatusCode == model.StatusCode.Value,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.StatusCode), "Geçerli bir oyun statüsü seçiniz.");
        }

        var validJuryIds = await context.Users
            .AsNoTracking()
            .Where(user => model.SelectedJuryIds.Contains(user.Id) &&
                           user.IsPublished &&
                           user.IsActive &&
                           user.RoleCode == 2)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);
        if (validJuryIds.Count == 0)
        {
            ModelState.AddModelError(nameof(model.SelectedJuryIds), "En az bir jüri veya jüri grubu seçiniz.");
        }
        else if (validJuryIds.Count != model.SelectedJuryIds.Count)
        {
            ModelState.AddModelError(nameof(model.SelectedJuryIds), "Jüri seçimlerinden biri artık kullanılamıyor.");
        }

        if (!ModelState.IsValid)
        {
            return await ReturnAddPlayFailureAsync(
                model,
                "Oyun kaydı oluşturulamadı. Lütfen zorunlu alanları kontrol ediniz.",
                cancellationToken);
        }

        var similarity = await GetAddPlaySimilarityAsync(
            model.PlayName,
            model.TheaterName,
            cancellationToken);
        if (similarity.HasExactMatch)
        {
            return await ReturnAddPlayFailureAsync(
                model,
                "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin.",
                cancellationToken);
        }

        if (similarity.SimilarPlays.Count > 0 && !model.ConfirmSimilarPlay)
        {
            return await ReturnAddPlayFailureAsync(
                model,
                "Benzer oyun kaydı bulundu. Kaydetmeden önce benzer kayıt onayı vermelisiniz.",
                cancellationToken);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        try
        {
            await using var transaction = await context.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            // Recheck under a serializable transaction to prevent concurrent exact duplicates.
            var finalSimilarity = await GetAddPlaySimilarityAsync(
                model.PlayName,
                model.TheaterName,
                cancellationToken);
            if (finalSimilarity.HasExactMatch)
            {
                await transaction.RollbackAsync(cancellationToken);
                return await ReturnAddPlayFailureAsync(
                    model,
                    "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin.",
                    cancellationToken);
            }

            var baseSlug = SlugHelper.Create(model.PlayName);
            var slug = baseSlug;
            var suffix = 2;
            while (await context.Plays.AsNoTracking().AnyAsync(play => play.Slug == slug, cancellationToken))
            {
                slug = $"{baseSlug}-{suffix++}";
            }

            var now = TurkeyTime.Now;
            var playId = Guid.NewGuid();
            context.Plays.Add(new Play
            {
                Id = playId,
                PlayName = model.PlayName,
                TheaterName = model.TheaterName,
                StatusCode = model.StatusCode!.Value,
                CreatedAt = now,
                CreatedBy = currentUserId,
                IsPublished = true,
                Slug = slug,
                RecordType = true,
                JuriOylamaStatus = false,
                KunyeGirisStatus = false
            });

            // JuryAssignedPlay navigations are intentionally ignored in AfifeContext,
            // so persist the principal row before inserting its dependent assignments.
            await context.SaveChangesAsync(cancellationToken);

            context.JuryAssignedPlays.AddRange(validJuryIds.Select(juryId => new JuryAssignedPlay
            {
                Id = Guid.NewGuid(),
                PlayId = playId,
                JuryId = juryId,
                CreatedAt = now,
                CreatedBy = currentUserId,
                IsPublished = true
            }));

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(
                exception,
                "Oyun kaydı oluşturulamadı. Oyun adı: {PlayName}, tiyatro adı: {TheaterName}",
                model.PlayName,
                model.TheaterName);
            return await ReturnAddPlayFailureAsync(
                model,
                "Oyun kaydedilirken bir hata oluştu. Lütfen tekrar deneyiniz.",
                cancellationToken);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Oyun başarıyla eklendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Plays)) ?? "/oyunlar";
        return RedirectToAction(nameof(AddPlay));
    }
    [HttpGet("oyunlar/{slug}/duzenle")]
    public async Task<IActionResult> EditPlay(
        string slug,
        string? returnUrl,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays.AsNoTracking()
            .SingleOrDefaultAsync(item => item.IsPublished && item.Slug == slug, cancellationToken);
        if (play is null)
        {
            play = (await context.Plays.AsNoTracking()
                    .Where(item => item.IsPublished && (item.Slug == null || item.Slug == string.Empty))
                    .OrderBy(item => item.Id)
                    .ToListAsync(cancellationToken))
                .FirstOrDefault(item => string.Equals(
                    SlugHelper.Create(item.PlayName),
                    slug,
                    StringComparison.OrdinalIgnoreCase));
        }
        if (play is null) return NotFound();

        var model = new EditPlayViewModel
        {
            Id = play.Id,
            Slug = SlugHelper.Resolve(play.Slug, play.PlayName),
            ReturnUrl = NormalizePlayReturnUrl(returnUrl),
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            StatusCode = play.StatusCode,
            RecordType = play.RecordType,
            JuriOylamaStatus = play.JuriOylamaStatus,
            KunyeGirisStatus = !play.RecordType && play.KunyeGirisStatus,
            SelectedJuryIds = await context.JuryAssignedPlays.AsNoTracking()
                .Where(item => item.PlayId == play.Id && item.IsPublished)
                .Select(item => item.JuryId)
                .Distinct()
                .ToListAsync(cancellationToken)
        };
        await PopulateAddPlayOptionsAsync(model, cancellationToken, includeActiveStatus: !play.RecordType);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("oyunlar/{slug}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditPlay(
        string slug,
        EditPlayViewModel model,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays.SingleOrDefaultAsync(
            item => item.Id == model.Id && item.IsPublished,
            cancellationToken);
        if (play is null) return NotFound();
        if (!string.Equals(
                SlugHelper.Resolve(play.Slug, play.PlayName),
                slug,
                StringComparison.OrdinalIgnoreCase))
        {
            return NotFound();
        }

        model.ReturnUrl = NormalizePlayReturnUrl(model.ReturnUrl);
        model.RecordType = play.RecordType;
        model.Slug = SlugHelper.Resolve(play.Slug, play.PlayName);
        model.PlayName = model.PlayName?.Trim() ?? string.Empty;
        model.TheaterName = model.TheaterName?.Trim() ?? string.Empty;
        model.SelectedJuryIds = model.SelectedJuryIds?.Distinct().ToList() ?? [];

        var validStatus = model.StatusCode.HasValue && await context.PlayStatuses.AsNoTracking().AnyAsync(
            status => status.IsPublished &&
                      status.StatusCode == model.StatusCode.Value &&
                      (!play.RecordType || status.StatusCode != 1),
            cancellationToken);
        if (!validStatus)
        {
            ModelState.AddModelError(nameof(model.StatusCode), "Geçerli bir oyun statüsü seçiniz.");
        }

        var validJuryIds = await context.Users.AsNoTracking()
            .Where(user => model.SelectedJuryIds.Contains(user.Id) &&
                           user.IsPublished && user.IsActive && user.RoleCode == 2)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);
        if (validJuryIds.Count != model.SelectedJuryIds.Count)
        {
            ModelState.AddModelError(nameof(model.SelectedJuryIds), "Jüri seçimlerinden biri artık kullanılamıyor.");
        }

        if (!ModelState.IsValid)
        {
            return await ReturnEditPlayFailureAsync(model, "Oyun güncellenemedi. Lütfen zorunlu alanları kontrol ediniz.", cancellationToken);
        }

        var similarity = await GetAddPlaySimilarityAsync(
            model.PlayName, model.TheaterName, cancellationToken, play.Id);
        if (similarity.HasExactMatch)
        {
            return await ReturnEditPlayFailureAsync(model,
                "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin.",
                cancellationToken);
        }
        if (similarity.SimilarPlays.Count > 0 && !model.ConfirmSimilarPlay)
        {
            return await ReturnEditPlayFailureAsync(model,
                "Benzer oyun kaydı bulundu. Kaydetmeden önce benzer kayıt onayı vermelisiniz.",
                cancellationToken);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        try
        {
            await using var transaction = await context.Database.BeginTransactionAsync(
                IsolationLevel.Serializable, cancellationToken);
            var finalSimilarity = await GetAddPlaySimilarityAsync(
                model.PlayName, model.TheaterName, cancellationToken, play.Id);
            if (finalSimilarity.HasExactMatch)
            {
                await transaction.RollbackAsync(cancellationToken);
                return await ReturnEditPlayFailureAsync(model,
                    "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin.",
                    cancellationToken);
            }

            var baseSlug = SlugHelper.Create(model.PlayName);
            var newSlug = baseSlug;
            var suffix = 2;
            while (await context.Plays.AsNoTracking().AnyAsync(
                       item => item.Id != play.Id && item.Slug == newSlug,
                       cancellationToken))
            {
                newSlug = $"{baseSlug}-{suffix++}";
            }

            play.PlayName = model.PlayName;
            play.TheaterName = model.TheaterName;
            play.StatusCode = model.StatusCode!.Value;
            play.Slug = newSlug;
            play.JuriOylamaStatus = model.JuriOylamaStatus;
            play.KunyeGirisStatus = !play.RecordType && model.KunyeGirisStatus;
            play.UpdatedAt = TurkeyTime.Now;
            play.UpdatedBy = currentUserId;

            var assignments = await context.JuryAssignedPlays
                .Where(item => item.PlayId == play.Id)
                .ToListAsync(cancellationToken);
            var selectedSet = validJuryIds.ToHashSet();
            foreach (var assignment in assignments)
            {
                assignment.IsPublished = selectedSet.Contains(assignment.JuryId);
                assignment.UpdatedAt = TurkeyTime.Now;
                assignment.UpdatedBy = currentUserId;
            }
            var existingJuryIds = assignments.Select(item => item.JuryId).ToHashSet();
            context.JuryAssignedPlays.AddRange(validJuryIds
                .Where(juryId => !existingJuryIds.Contains(juryId))
                .Select(juryId => new JuryAssignedPlay
                {
                    Id = Guid.NewGuid(),
                    PlayId = play.Id,
                    JuryId = juryId,
                    CreatedAt = TurkeyTime.Now,
                    CreatedBy = currentUserId,
                    IsPublished = true
                }));

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            TempData["GenericPopup.Type"] = "success";
            TempData["GenericPopup.Message"] = "Oyun başarıyla güncellendi.";
            return RedirectToAction(nameof(PlayDetails), new { slug = newSlug, returnUrl = model.ReturnUrl });
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Oyun güncellenemedi. PlayId: {PlayId}", play.Id);
            return await ReturnEditPlayFailureAsync(model,
                "Oyun güncellenirken bir hata oluştu. Lütfen tekrar deneyiniz.",
                cancellationToken);
        }
    }

    private async Task<IActionResult> ReturnEditPlayFailureAsync(
        EditPlayViewModel model,
        string message,
        CancellationToken cancellationToken)
    {
        model.ConfirmSimilarPlay = false;
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = message;
        await PopulateAddPlayOptionsAsync(model, cancellationToken, includeActiveStatus: !model.RecordType);
        return View(nameof(EditPlay), model);
    }
    private async Task<IActionResult> UpdatePlayStatus(
        Guid id,
        bool isActive,
        bool isJuryVotingStatus,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (play is null)
        {
            return NotFound();
        }

        if (play.RecordType && !isJuryVotingStatus)
        {
            var requiresNormalization = play.KunyeGirisStatus;
            play.KunyeGirisStatus = false;
            if (requiresNormalization)
            {
                play.UpdatedAt = TurkeyTime.Now;
                play.UpdatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var normalizingUserId)
                    ? normalizingUserId
                    : null;
                await context.SaveChangesAsync(cancellationToken);
            }

            return Json(new { isActive = false, isDisabled = true, refreshTable = false });
        }

        var updatedAt = TurkeyTime.Now;
        Guid? updatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
            ? userId
            : null;
        var eligibleRecords = context.Plays.Where(item =>
            item.Id == id &&
            item.IsPublished &&
            (isJuryVotingStatus || !item.RecordType));

        var updatedRowCount = isJuryVotingStatus
            ? await eligibleRecords.ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(item => item.JuriOylamaStatus, isActive)
                    .SetProperty(item => item.UpdatedAt, updatedAt)
                    .SetProperty(item => item.UpdatedBy, updatedBy),
                cancellationToken)
            : await eligibleRecords.ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(item => item.KunyeGirisStatus, isActive)
                    .SetProperty(item => item.UpdatedAt, updatedAt)
                    .SetProperty(item => item.UpdatedBy, updatedBy),
                cancellationToken);

        if (updatedRowCount == 0)
        {
            return Conflict(new { message = "Künye giriş oyunu statüsü güncellenemedi." });
        }

        return Json(new { isActive, refreshTable = false });
    }
    [HttpGet("oyunlar/{slug}")]
    public async Task<IActionResult> PlayDetails(
        string slug,
        string? returnUrl,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.IsPublished && item.Slug == slug,
                cancellationToken);

        if (play is null)
        {
            var sluglessPlays = await context.Plays
                .AsNoTracking()
                .Where(item => item.IsPublished && (item.Slug == null || item.Slug == string.Empty))
                .OrderBy(item => item.Id)
                .ToListAsync(cancellationToken);

            play = sluglessPlays.FirstOrDefault(item =>
                string.Equals(SlugHelper.Create(item.PlayName), slug, StringComparison.OrdinalIgnoreCase));
        }

        if (play is null)
        {
            return NotFound();
        }

        var playStatus = await context.PlayStatuses
            .AsNoTracking()
            .Where(status => status.StatusCode == play.StatusCode)
            .Select(status => new { status.StatusName, status.StatusColor })
            .SingleOrDefaultAsync(cancellationToken);

        var assignedJuries = await (
            from assignment in context.JuryAssignedPlays.AsNoTracking()
            join user in context.Users.AsNoTracking()
                on assignment.JuryId equals user.Id
            where assignment.PlayId == play.Id
               && assignment.IsPublished
               && user.IsPublished
               && user.RoleCode == 2
            select new
            {
                user.Id,
                user.GroupCode,
                user.FirstName,
                user.LastName,
                user.Username
            })
            .Distinct()
            .ToArrayAsync(cancellationToken);

        var assignedGroupCodes = assignedJuries
            .Where(jury => jury.GroupCode.HasValue)
            .Select(jury => jury.GroupCode!.Value)
            .Distinct()
            .ToArray();
        var assignedGroupNames = await context.Groups
            .AsNoTracking()
            .Where(group => assignedGroupCodes.Contains(group.Code) && group.IsPublished)
            .ToDictionaryAsync(group => group.Code, group => group.GroupName, cancellationToken);

        var selectableGroupMembers = await context.Users
            .AsNoTracking()
            .Where(user => user.IsPublished &&
                           user.IsActive &&
                           user.RoleCode == 2 &&
                           user.GroupCode.HasValue &&
                           assignedGroupCodes.Contains(user.GroupCode.Value))
            .Select(user => new { GroupCode = user.GroupCode!.Value, user.Id })
            .ToArrayAsync(cancellationToken);
        var selectableMemberIdsByGroup = selectableGroupMembers
            .GroupBy(member => member.GroupCode)
            .ToDictionary(group => group.Key, group => group.Select(member => member.Id).ToHashSet());

        static string JuryDisplayName(string firstName, string lastName, string username)
        {
            var fullName = $"{firstName} {lastName}".Trim();
            return string.IsNullOrWhiteSpace(fullName) ? username : fullName;
        }

        var juryGroupInfo = assignedJuries
            .GroupBy(jury => jury.GroupCode)
            .SelectMany(group =>
            {
                if (group.Key.HasValue &&
                    assignedGroupNames.TryGetValue(group.Key.Value, out var groupName) &&
                    selectableMemberIdsByGroup.TryGetValue(group.Key.Value, out var selectableMemberIds) &&
                    selectableMemberIds.Count > 0 &&
                    selectableMemberIds.All(memberId => group.Any(jury => jury.Id == memberId)))
                {
                    return new[] { groupName };
                }

                return group.Select(jury =>
                    JuryDisplayName(jury.FirstName, jury.LastName, jury.Username));
            })
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.CurrentCultureIgnoreCase)
            .OrderBy(value => value, StringComparer.CurrentCultureIgnoreCase)
            .ToArray();

        var auditUserIds = new[] { play.CreatedBy, play.UpdatedBy }
            .Where(userId => userId.HasValue)
            .Select(userId => userId!.Value)
            .Distinct()
            .ToArray();
        var auditUsers = await context.Users
            .AsNoTracking()
            .Where(user => auditUserIds.Contains(user.Id))
            .Select(user => new
            {
                user.Id,
                FullName = (user.FirstName + " " + user.LastName).Trim()
            })
            .ToDictionaryAsync(user => user.Id, user => user.FullName, cancellationToken);

        ComplexTableViewModel? candidatesTable = null;
        if (!play.RecordType)
        {
            var candidateReport = await candidateReportService.GetPageAsync(
                new CandidateTableQuery { PlayId = play.Id },
                cancellationToken);
            candidatesTable = CandidateComplexTableFactory.Create(candidateReport);
        }
        var normalizedReturnUrl = NormalizePlayReturnUrl(returnUrl);

        return View(new PlayDetailsViewModel
        {
            Id = play.Id,
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            JuriOylamaStatus = play.JuriOylamaStatus,
            KunyeGirisStatus = !play.RecordType && play.KunyeGirisStatus,
            JuryGroupInfo = juryGroupInfo.Length == 0 ? "-" : string.Join(", ", juryGroupInfo),
            PlayStatus = playStatus?.StatusName ?? "-",
            PlayStatusColor = NormalizeStatusColor(playStatus?.StatusColor),
            RecordType = play.RecordType,
            CreatedAt = play.CreatedAt,
            CreatedByName = play.CreatedBy.HasValue && auditUsers.TryGetValue(play.CreatedBy.Value, out var creator)
                ? creator
                : null,
            UpdatedAt = play.UpdatedAt,
            UpdatedByName = play.UpdatedBy.HasValue && auditUsers.TryGetValue(play.UpdatedBy.Value, out var updater)
                ? updater
                : null,
            Slug = SlugHelper.Resolve(play.Slug, play.PlayName),
            ReturnUrl = normalizedReturnUrl,
            ReturnLabel = GetPlayReturnLabel(normalizedReturnUrl),
            CandidatesTable = candidatesTable
        });
    }
    [AdminMutationAudit]
    [HttpPost("oyunlar/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeletePlay(
        Guid id,
        [FromForm] string? returnUrl,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (play is null) return NotFound();

        var normalizedReturnUrl = NormalizePlayReturnUrl(returnUrl);
        var playSlug = SlugHelper.Resolve(play.Slug, play.PlayName);
        if (!play.RecordType)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Künye Giriş Sistemi kaynaklı oyunlar silinemez.";
            return RedirectToAction(nameof(PlayDetails), new
            {
                slug = playSlug,
                returnUrl = normalizedReturnUrl
            });
        }
        var now = TurkeyTime.Now;
        Guid? currentUserId = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
            ? userId
            : null;

        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            var candidateIds = await context.PlayAwardCategories
                .AsNoTracking()
                .Where(candidate => candidate.PlayId == play.Id && candidate.IsPublished)
                .Select(candidate => candidate.Id)
                .ToArrayAsync(cancellationToken);

            await context.JuryVotes
                .Where(vote => candidateIds.Contains(vote.PlayAwardCategoryId) && vote.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(vote => vote.IsPublished, false)
                    .SetProperty(vote => vote.IsActive, false)
                    .SetProperty(vote => vote.UpdatedAt, now)
                    .SetProperty(vote => vote.UpdatedBy, currentUserId), cancellationToken);

            await context.PlayAwardCategories
                .Where(candidate => candidate.PlayId == play.Id && candidate.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(candidate => candidate.IsPublished, false)
                    .SetProperty(candidate => candidate.IsActive, false)
                    .SetProperty(candidate => candidate.UpdatedAt, now)
                    .SetProperty(candidate => candidate.UpdatedBy, currentUserId), cancellationToken);

            await context.JuryAssignedPlays
                .Where(assignment => assignment.PlayId == play.Id && assignment.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(assignment => assignment.IsPublished, false)
                    .SetProperty(assignment => assignment.UpdatedAt, now)
                    .SetProperty(assignment => assignment.UpdatedBy, currentUserId), cancellationToken);

            await context.JuryGameTicketFees
                .Where(fee => fee.PlayId == play.Id && fee.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(fee => fee.IsPublished, false)
                    .SetProperty(fee => fee.UpdatedAt, now)
                    .SetProperty(fee => fee.UpdatedBy, currentUserId), cancellationToken);

            await context.Blacklists
                .Where(blacklist => blacklist.PlayId == play.Id && blacklist.IsPublished)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(blacklist => blacklist.IsPublished, false), cancellationToken);

            play.IsPublished = false;
            play.UpdatedAt = now;
            play.UpdatedBy = currentUserId;
            await context.SaveChangesAsync(cancellationToken);

            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogError(exception, "Oyun soft-delete işlemi tamamlanamadı. PlayId: {PlayId}", play.Id);
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Oyun silinemedi. Lütfen tekrar deneyiniz.";
            return RedirectToAction(nameof(PlayDetails), new
            {
                slug = playSlug,
                returnUrl = normalizedReturnUrl
            });
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Oyun başarıyla silindi.";
        return LocalRedirect(normalizedReturnUrl);
    }
    [HttpPost("oyunlar/adaylar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CandidateTable(
        [FromForm] CandidateTableQuery query,
        CancellationToken cancellationToken)
    {
        if (!await context.Plays.AsNoTracking().AnyAsync(
                play => play.Id == query.PlayId && play.IsPublished && !play.RecordType,
                cancellationToken))
        {
            return NotFound();
        }

        var report = await candidateReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = CandidateComplexTableFactory.Create(report) });
    }

    [AdminMutationAudit]
    [HttpPost("adaylar/{id:guid}/status")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateCandidateStatus(
        Guid id,
        [FromForm] bool isActive,
        CancellationToken cancellationToken)
    {
        var candidate = await context.PlayAwardCategories.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (candidate is null) return NotFound();

        candidate.IsActive = isActive;
        candidate.UpdatedAt = TurkeyTime.Now;
        candidate.UpdatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
            ? userId
            : null;
        try
        {
            await context.SaveChangesAsync(cancellationToken);
            return Json(new { isActive, refreshTable = false });
        }
        catch (DbUpdateException exception)
        {
            logger.LogError(exception, "Aday statüsü güncellenemedi. CandidateId: {CandidateId}", id);
            return Conflict(new { message = "Aday statüsü güncellenemedi. Lütfen tekrar deneyiniz." });
        }
    }

    [AdminMutationAudit]
    [HttpPost("adaylar/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteCandidate(Guid id, CancellationToken cancellationToken)
    {
        var candidate = await context.PlayAwardCategories
            .Include(item => item.Play)
            .SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (candidate is null)
        {
            return IsAjaxRequest()
                ? NotFound(new { message = "Aday kaydı bulunamadı." })
                : NotFound();
        }
        if (CandidateCategoryPolicy.IsSystemManaged(candidate.AwardCategoryCode))
        {
            const string protectedCategoryMessage = "Sistem tarafından yönetilen oyun kategorisi silinemez.";
            if (IsAjaxRequest())
            {
                return BadRequest(new { message = protectedCategoryMessage });
            }

            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = protectedCategoryMessage;
            return RedirectToAction(nameof(PlayDetails), new { slug = SlugHelper.Resolve(candidate.Play.Slug, candidate.Play.PlayName) });
        }

        candidate.IsActive = false;
        candidate.IsPublished = false;
        candidate.UpdatedAt = TurkeyTime.Now;
        candidate.UpdatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
            ? userId
            : null;
        if (candidate.PhotoImageId.HasValue)
        {
            var photo = await context.Images.SingleOrDefaultAsync(
                image => image.Id == candidate.PhotoImageId.Value && image.IsPublished,
                cancellationToken);
            if (photo is not null)
            {
                photo.IsPublished = false;
                photo.UpdatedAt = candidate.UpdatedAt;
                photo.UpdatedBy = candidate.UpdatedBy;
            }
        }
        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception)
        {
            logger.LogError(exception, "Aday kaydı silinemedi. CandidateId: {CandidateId}", id);
            const string deleteErrorMessage = "Aday kaydı silinemedi. Lütfen tekrar deneyiniz.";
            if (IsAjaxRequest())
            {
                return Conflict(new { message = deleteErrorMessage });
            }

            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = deleteErrorMessage;
            return RedirectToAction(nameof(PlayDetails), new { slug = SlugHelper.Resolve(candidate.Play.Slug, candidate.Play.PlayName) });
        }

        if (IsAjaxRequest())
        {
            return Json(new { success = true, message = "Aday kaydı silindi.", refreshTable = true });
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Aday kaydı silindi.";
        return RedirectToAction(nameof(PlayDetails), new { slug = SlugHelper.Resolve(candidate.Play.Slug, candidate.Play.PlayName) });
    }

    [HttpGet("adaylar/{id:guid}")]
    public Task<IActionResult> CandidateDetails(Guid id, CancellationToken cancellationToken) =>
        CandidateDetailsCoreAsync(id, cancellationToken);

    [HttpPost("oyunlar/{id:guid}/tum-oylari-yazdir")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportPlayVotes(Guid id, CancellationToken cancellationToken)
    {
        var play = await context.Plays.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished && !item.RecordType)
            .Select(item => new { item.Id, item.PlayName })
            .SingleOrDefaultAsync(cancellationToken);
        if (play is null) return NotFound();

        var rows = await (
            from vote in context.JuryVotes.AsNoTracking()
            join candidate in context.PlayAwardCategories.AsNoTracking()
                on vote.PlayAwardCategoryId equals candidate.Id
            join category in context.AwardCategories.AsNoTracking()
                on candidate.AwardCategoryCode equals category.CategoryCode
            join jury in context.Users.AsNoTracking() on vote.JuryId equals jury.Id
            where candidate.PlayId == id
               && vote.IsPublished
               && candidate.IsPublished
               && category.IsPublished
               && jury.IsPublished
            orderby jury.FirstName, jury.LastName, category.CategoryCode, candidate.RoleCode
            select new PlayVoteExportRowViewModel
            {
                JuryName = (jury.FirstName + " " + jury.LastName).Trim(),
                CategoryName = category.CategoryName,
                RoleName = candidate.Role ?? string.Empty,
                Score = vote.Score,
                VoteDate = vote.CreatedAt,
                IsActive = vote.IsActive
            }).ToArrayAsync(cancellationToken);

        var content = excelExporter.Export(PlayVoteExcelExportFactory.Create(play.PlayName, rows));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"{SlugHelper.Create(play.PlayName)}-tum-oylar.xlsx");
    }

    [HttpPost("oyunlar/adaylar/yazdir")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportCandidates(
        [FromForm] CandidateTableQuery query,
        CancellationToken cancellationToken)
    {
        var play = await context.Plays.AsNoTracking()
            .Where(item => item.Id == query.PlayId && item.IsPublished && !item.RecordType)
            .Select(item => new { item.PlayName })
            .SingleOrDefaultAsync(cancellationToken);
        if (play is null) return NotFound();

        var rows = await candidateReportService.GetExportRowsAsync(query, cancellationToken);
        var content = excelExporter.Export(CandidateExcelExportFactory.Create(play.PlayName, rows, query));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"{SlugHelper.Create(play.PlayName)}-adaylar.xlsx");
    }
    [AdminMutationAudit]
    [HttpPost("oyunlar/{slug}/aday-ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddCandidate(
        string slug,
        [Bind(Prefix = "Input")] AddCandidateInputModel input,
        CancellationToken cancellationToken)
    {
        var play = input.PlayId.HasValue
            ? await context.Plays
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.Id == input.PlayId.Value && item.IsPublished && !item.RecordType,
                    cancellationToken)
            : null;

        if (play is null ||
            !string.Equals(SlugHelper.Resolve(play.Slug, play.PlayName), slug, StringComparison.OrdinalIgnoreCase))
        {
            return NotFound();
        }

        input.PlayId = play.Id;
        input.Candidate = input.Candidate?.Trim() ?? string.Empty;
        input.Role = string.IsNullOrWhiteSpace(input.Role) ? null : input.Role.Trim();
        var isChangeMode = string.Equals(input.Mode, "change", StringComparison.Ordinal);
        if (!isChangeMode && !string.Equals(input.Mode, "new", StringComparison.Ordinal))
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Geçerli bir aday işlem türü seçiniz.");
        }

        var category = input.AwardCategoryCode.HasValue
            ? await context.AwardCategories
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.IsPublished &&
                            item.CategoryCode == input.AwardCategoryCode.Value &&
                            item.CategoryCode != CandidateCategoryPolicy.BestPlayCategoryCode &&
                            item.CategoryCode != CandidateCategoryPolicy.BestDirectorCategoryCode,
                    cancellationToken)
            : null;
        if (category is null)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Geçerli bir ödül kategorisi seçiniz.");
        }

        var categorySupportsRoleAndPhoto =
            CandidateCategoryPolicy.SupportsRoleAndPhoto(category.CategoryCode);
        if (!categorySupportsRoleAndPhoto)
        {
            input.Role = null;
        }

        if (input.Candidate.Length is < 2 or > 250)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Adı Soyadı alanı 2 ile 250 karakter arasında olmalıdır.");
        }

        if (!input.IsActive.HasValue)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Statü seçimi zorunludur.");
        }

        if (categorySupportsRoleAndPhoto && input.Role is null && !isChangeMode)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Rol Adı alanı zorunludur.");
        }

        if (input.Role?.Length > 200)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Rol Adı en fazla 200 karakter olabilir.");
        }

        byte[]? photoData = null;
        string? photoContentType = null;
        string? photoFileName = null;
        if (!categorySupportsRoleAndPhoto && input.Photo is not null)
        {
            return RedirectToCandidateSectionWithPopup(
                slug, "fail", "Bu ödül kategorisine fotoğraf eklenemez.");
        }

        if (categorySupportsRoleAndPhoto && input.Photo is not null)
        {
            if (input.Photo.Length == 0 ||
                input.Photo.Length > ImageUploadPolicy.MaximumFileSizeBytes)
            {
                return RedirectToCandidateSectionWithPopup(
                    slug, "fail", ImageUploadPolicy.MaximumFileSizeMessage);
            }

            await using var photoStream = new MemoryStream();
            await input.Photo.CopyToAsync(photoStream, cancellationToken);
            photoData = photoStream.ToArray();
            photoContentType = input.Photo.ContentType.Trim().ToLowerInvariant();
            photoFileName = Path.GetFileName(input.Photo.FileName);
            if (!IsSupportedPhoto(photoData, photoContentType, photoFileName))
            {
                return RedirectToCandidateSectionWithPopup(
                    slug,
                    "fail",
                    "Yalnızca JPEG, PNG veya WebP formatında fotoğraf yükleyebilirsiniz.");
            }
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        await using var transaction = await context.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
        try
        {
            var publishedPlayCandidates = await context.PlayAwardCategories
                .Where(item => item.PlayId == play.Id && item.IsPublished)
                .OrderByDescending(item => item.IsCurrent)
                .ThenByDescending(item => item.UpdatedAt ?? item.CreatedAt)
                .ThenByDescending(item => item.Id)
                .ToListAsync(cancellationToken);
            var categoryCandidates = publishedPlayCandidates
                .Where(item => item.AwardCategoryCode == category.CategoryCode)
                .ToArray();
            var candidateTextComparer = StringComparer.Create(
                new System.Globalization.CultureInfo("tr-TR"),
                true);

            int roleCode;
            string? role;
            int? sourceFormCandidateOrder = null;
            if (isChangeMode)
            {
                if (!input.ReplacedCandidateId.HasValue)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        "Değişimi yapılacak aday/rol seçimi zorunludur.");
                }

                var replacedCandidate = categoryCandidates.SingleOrDefault(item =>
                    item.Id == input.ReplacedCandidateId.Value && item.IsCurrent);
                if (replacedCandidate is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        "Değişimi yapılacak güncel aday/rol bulunamadı.");
                }

                roleCode = replacedCandidate.RoleCode;
                role = replacedCandidate.Role;
                sourceFormCandidateOrder = replacedCandidate.SourceFormCandidateOrder;
                if (categorySupportsRoleAndPhoto && string.IsNullOrWhiteSpace(role))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        "Seçilen adayın rol bilgisi eksik olduğu için değişim yapılamadı.");
                }

                var duplicateReplacement = categoryCandidates.Any(item =>
                    item.RoleCode == roleCode &&
                    candidateTextComparer.Equals(item.Candidate.Trim(), input.Candidate));
                if (duplicateReplacement)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        "Aynı aday bu kategori ve rol için daha önce kaydedilmiş.");
                }

                replacedCandidate.IsCurrent = false;
                replacedCandidate.UpdatedAt = TurkeyTime.Now;
                replacedCandidate.UpdatedBy = currentUserId;
            }
            else if (category.MultiCandidate)
            {
                role = input.Role;
                var usedRoleCodes = publishedPlayCandidates
                    .Where(item => item.RoleCode > 0)
                    .Select(item => item.RoleCode)
                    .ToHashSet();
                roleCode = GenerateUniqueRoleCode(usedRoleCodes);
            }
            else
            {
                if (categoryCandidates.Length > 0)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        "Bu kategori için bir aday kaydı mevcut. Aday/Rol Değişimi seçeneğini kullanınız.");
                }

                role = null;
                roleCode = 0;
            }

            Guid? photoImageId = null;
            var now = TurkeyTime.Now;
            if (photoData is not null && photoContentType is not null && photoFileName is not null)
            {
                photoImageId = Guid.NewGuid();
                context.Images.Add(new Image
                {
                    Id = photoImageId.Value,
                    FileName = photoFileName,
                    ContentType = photoContentType,
                    ImageData = photoData,
                    CreatedAt = now,
                    CreatedBy = currentUserId,
                    IsPublished = true
                });
            }

            context.PlayAwardCategories.Add(new PlayAwardCategory
            {
                Id = Guid.NewGuid(),
                PlayId = play.Id,
                PhotoImageId = photoImageId,
                CreatedAt = now,
                CreatedBy = currentUserId,
                IsPublished = true,
                IsActive = input.IsActive.Value,
                Candidate = input.Candidate,
                AwardCategoryCode = category.CategoryCode,
                IsCurrent = true,
                Role = role,
                RoleCode = roleCode,
                SourceFormCandidateOrder = sourceFormCandidateOrder
            });

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogWarning(
                exception,
                "Aday kaydı oluşturulamadı. PlayId: {PlayId}, CategoryCode: {CategoryCode}",
                play.Id,
                category.CategoryCode);
            return RedirectToCandidateSectionWithPopup(
                slug,
                "fail",
                "Aday kaydı oluşturulamadı. Kategori ve rol bilgilerini kontrol ederek tekrar deneyiniz.");
        }

        var successMessage = isChangeMode
            ? "Aday / Rol değişimi başarıyla kaydedildi."
            : "Aday başarıyla eklendi.";
        return RedirectToCandidateSectionWithPopup(slug, "success", successMessage);
    }

    private IActionResult RedirectToCandidateSectionWithPopup(string slug, string type, string message)
    {
        TempData["GenericPopup.Type"] = type;
        TempData["GenericPopup.Message"] = message;
        return RedirectToCandidateSection(slug);
    }

    private IActionResult RedirectToCandidateSection(string slug)
    {
        var detailsUrl = Url.Action(nameof(PlayDetails), new { slug }) ?? $"/oyunlar/{slug}";
        return Redirect(detailsUrl + "#aday-ekle");
    }

    private static int GenerateUniqueRoleCode(IReadOnlySet<int> usedRoleCodes)
    {
        const int maximumRoleCode = 9999;
        if (usedRoleCodes.Count >= maximumRoleCode)
        {
            throw new InvalidOperationException("Bu oyun için kullanılabilir rol kodu kalmadı.");
        }

        var randomStart = RandomNumberGenerator.GetInt32(1, maximumRoleCode + 1);
        for (var offset = 0; offset < maximumRoleCode; offset++)
        {
            var candidateCode = 1 + ((randomStart - 1 + offset) % maximumRoleCode);
            if (!usedRoleCodes.Contains(candidateCode))
            {
                return candidateCode;
            }
        }

        throw new InvalidOperationException("Benzersiz rol kodu üretilemedi.");
    }

    private static string NormalizeStatusColor(string? color)
    {
        if (string.IsNullOrWhiteSpace(color))
        {
            return "#6b7280";
        }

        var value = color.Trim();
        if (value.Length is not (4 or 7 or 9) || value[0] != '#' ||
            value.Skip(1).Any(character => !Uri.IsHexDigit(character)))
        {
            return "#6b7280";
        }

        return value;
    }
    [HttpGet("siralamalar")]
    public async Task<IActionResult> Rankings(CancellationToken cancellationToken)
    {
        var report = await rankingReportService.GetPageAsync(
            new RankingTableQuery(),
            cancellationToken);
        return View(new RankingsDashboardViewModel
        {
            Table = RankingComplexTableFactory.Create(report)
        });
    }

    [HttpPost("siralamalar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RankingsTable(
        [FromForm] RankingTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await rankingReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new
        {
            model = RankingComplexTableFactory.Create(report)
        });
    }

    [HttpPost("siralamalar/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportRankings(
        [FromForm] RankingTableQuery query,
        [FromForm] string exportScope,
        CancellationToken cancellationToken)
    {
        var currentPageOnly = !string.Equals(exportScope, "all", StringComparison.OrdinalIgnoreCase);
        var report = await rankingReportService.GetExportAsync(
            query,
            currentPageOnly,
            cancellationToken);
        var content = excelExporter.Export(RankingExcelExportFactory.Create(report, currentPageOnly));
        var scope = currentPageOnly ? $"sayfa-{report.CurrentPage}" : "tum-tablo";
        return File(
            content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"siralamalar-{scope}-{DateTime.Now:yyyyMMdd-HHmm}.xlsx");
    }

    [HttpGet("siralamalar/{playAwardCategoryId:guid}/oylar")]
    public async Task<IActionResult> RankingVotesModal(
        Guid playAwardCategoryId,
        CancellationToken cancellationToken)
    {
        var report = await rankingReportService.GetVotesPageAsync(
            new RankingVoteTableQuery { PlayAwardCategoryId = playAwardCategoryId }, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.PlayName)) return NotFound();
        return PartialView("_RankingVotesModal", new RankingVoteModalViewModel
        {
            PlayName = report.PlayName,
            Table = RankingVoteComplexTableFactory.Create(report)
        });
    }

    [HttpPost("siralamalar/oylar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RankingVotesTable(
        [FromForm] RankingVoteTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await rankingReportService.GetVotesPageAsync(query, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.PlayName)) return NotFound();
        return ViewComponent("ComplexTable", new { model = RankingVoteComplexTableFactory.Create(report) });
    }

    [HttpPost("siralamalar/oylar/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportRankingVotes(
        [FromForm] RankingVoteTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await rankingReportService.GetVotesExportAsync(query, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.PlayName)) return NotFound();
        var content = excelExporter.Export(RankingVoteExcelExportFactory.Create(report));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"juri-oylari-{DateTime.Now:yyyyMMdd-HHmm}.xlsx");
    }
    [HttpGet("editorler")]
    public IActionResult Editors() => Page("Editörler", "Editör hesaplarını yönetin.");

    [HttpGet("secenekler/oyunlar")]
    public async Task<IActionResult> PlayOptions(CancellationToken cancellationToken)
    {
        var options = await context.Plays
            .AsNoTracking()
            .Where(play => play.IsPublished && !play.RecordType)
            .OrderBy(play => play.PlayName)
            .Select(play => new { value = play.Id, text = play.PlayName })
            .ToArrayAsync(cancellationToken);
        return Json(options);
    }

    [HttpGet("secenekler/juriler")]
    public async Task<IActionResult> JuryOptions(CancellationToken cancellationToken)
    {
        var options = await context.Users
            .AsNoTracking()
            .Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2)
            .OrderBy(user => user.FirstName)
            .ThenBy(user => user.LastName)
            .Select(user => new
            {
                value = user.Id,
                text = (user.FirstName + " " + user.LastName).Trim()
            })
            .ToArrayAsync(cancellationToken);
        return Json(options);
    }

    [HttpGet("oylama-gecmisi")]
    public async Task<IActionResult> VotingHistory(
        Guid? playId,
        bool fromPlayDetails,
        string? returnUrl,
        CancellationToken cancellationToken)
    {
        if (!playId.HasValue)
        {
            return View(new VotingHistoryViewModel());
        }

        var play = await context.Plays
            .AsNoTracking()
            .Where(item => item.Id == playId.Value && item.IsPublished && !item.RecordType)
            .Select(item => new { item.Id, item.PlayName, item.Slug })
            .SingleOrDefaultAsync(cancellationToken);
        if (play is null) return NotFound();

        return View(new VotingHistoryViewModel
        {
            PlayId = play.Id,
            PlayName = play.PlayName,
            LockPlay = true,
            PlayDetailsUrl = fromPlayDetails
                ? Url.Action(nameof(PlayDetails), new
                {
                    slug = SlugHelper.Resolve(play.Slug, play.PlayName),
                    returnUrl = NormalizePlayReturnUrl(returnUrl)
                })
                : null
        });
    }

    [HttpGet("oylama-gecmisi/kategoriler")]
    public async Task<IActionResult> VotingHistoryCategories(
        Guid playId,
        Guid juryId,
        CancellationToken cancellationToken)
    {
        var playExists = await context.Plays.AsNoTracking().AnyAsync(
            play => play.Id == playId && play.IsPublished && !play.RecordType,
            cancellationToken);
        var juryExists = await context.Users.AsNoTracking().AnyAsync(
            user => user.Id == juryId && user.IsPublished && user.IsActive && user.RoleCode == 2,
            cancellationToken);
        if (!playExists || !juryExists) return BadRequest();

        var candidates = await (
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join category in context.AwardCategories.AsNoTracking()
                on candidate.AwardCategoryCode equals category.CategoryCode
            where candidate.PlayId == playId && candidate.IsPublished && category.IsPublished
            select new
            {
                candidate.Id,
                candidate.AwardCategoryCode,
                candidate.RoleCode,
                category.CategoryName,
                candidate.Candidate,
                candidate.Role,
                candidate.IsCurrent,
                HasVote = context.JuryVotes.AsNoTracking().Any(vote =>
                    vote.JuryId == juryId &&
                    vote.PlayAwardCategoryId == candidate.Id &&
                    vote.IsPublished)
            })
            .ToArrayAsync(cancellationToken);

        var categories = candidates
            .GroupBy(candidate => new
            {
                candidate.AwardCategoryCode,
                candidate.RoleCode,
                candidate.CategoryName
            })
            .OrderBy(group => group.Key.AwardCategoryCode)
            .ThenBy(group => group.Key.RoleCode)
            .Select(group =>
            {
                var ordered = group
                    .OrderByDescending(candidate => candidate.IsCurrent)
                    .ThenBy(candidate => candidate.Candidate)
                    .ToArray();
                var hasMultipleCandidates = ordered.Length > 1;
                var options = ordered.Select(candidate => new VotingHistoryCandidateViewModel
                {
                    Id = candidate.Id,
                    IsCurrent = candidate.IsCurrent,
                    HasVote = candidate.HasVote,
                    DisplayName = FormatCandidateName(
                        candidate.Candidate,
                        candidate.Role,
                        hasMultipleCandidates,
                        candidate.IsCurrent)
                }).ToArray();
                var selected = options
                    .OrderByDescending(candidate => candidate.HasVote)
                    .ThenByDescending(candidate => candidate.IsCurrent)
                    .First();

                return new VotingHistoryCategoryViewModel
                {
                    AwardCategoryCode = group.Key.AwardCategoryCode,
                    RoleCode = group.Key.RoleCode,
                    CategoryName = group.Key.CategoryName,
                    PlaceholderImageUrl = $"/images/awardCategoryPlaceholder/{group.Key.AwardCategoryCode}.svg",
                    SelectedCandidateId = selected.Id,
                    Candidates = options
                };
            })
            .ToArray();

        return PartialView("_VotingHistoryCards", new VotingHistoryCardsViewModel
        {
            PlayId = playId,
            JuryId = juryId,
            Categories = categories
        });
    }

    [AdminMutationAudit]
    [HttpPost("oylama-gecmisi/oylamayi-sifirla")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetJuryVote(
        Guid playId,
        Guid juryId,
        Guid playAwardCategoryId,
        CancellationToken cancellationToken)
    {
        var vote = await context.JuryVotes
            .SingleOrDefaultAsync(item =>
                item.JuryId == juryId &&
                item.PlayAwardCategoryId == playAwardCategoryId &&
                item.IsPublished &&
                context.PlayAwardCategories.Any(candidate =>
                    candidate.Id == item.PlayAwardCategoryId &&
                    candidate.PlayId == playId &&
                    candidate.IsPublished),
                cancellationToken);
        if (vote is null)
        {
            return BadRequest(new { success = false, message = "Sıfırlanabilecek bir oy bulunamadı." });
        }
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Unauthorized(new { success = false, message = "Oturum bilgisi doğrulanamadı." });
        }

        vote.IsPublished = false;
        vote.UpdatedAt = TurkeyTime.Now;
        vote.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


        return Json(new { success = true, message = "Oylama başarıyla sıfırlandı." });
    }

    [HttpGet("bilet-satislari")]
    public async Task<IActionResult> TicketSales(CancellationToken cancellationToken)
    {
        var report = await ticketSalesReportService.GetPageAsync(new TicketSalesTableQuery(), cancellationToken);
        return View(new TicketSalesViewModel { Table = TicketSalesComplexTableFactory.Create(report) });
    }

    [HttpPost("bilet-satislari/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> TicketSalesTable([FromForm] TicketSalesTableQuery query, CancellationToken cancellationToken)
    {
        var report = await ticketSalesReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = TicketSalesComplexTableFactory.Create(report) });
    }

    [HttpPost("bilet-satislari/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportTicketSales([FromForm] TicketSalesTableQuery query, CancellationToken cancellationToken)
    {
        var rows = await ticketSalesReportService.GetExportRowsAsync(query, cancellationToken);
        var content = excelExporter.Export(TicketSalesExcelExportFactory.Create(rows, query));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"bilet-satislari-{DateTime.Today:yyyy-MM-dd}.xlsx");
    }

    [HttpGet("bilet-satislari/{id:guid}/duzenle")]
    public async Task<IActionResult> EditTicketFee(Guid id, CancellationToken cancellationToken)
    {
        var model = await ticketSalesReportService.GetEditModelAsync(id, cancellationToken);
        return model is null ? NotFound() : PartialView("_EditTicketFeeModal", model);
    }

    [AdminMutationAudit]
    [HttpPost("bilet-satislari/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateTicketFee(Guid id, [Bind("Id,TicketFee")] EditTicketFeeViewModel model, CancellationToken cancellationToken)
    {
        if (id != model.Id || !ModelState.IsValid)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Geçerli bir bilet ücreti giriniz.";
            return RedirectToAction(nameof(TicketSales));
        }

        if (model.TicketFee < 1 || model.TicketFee > 99999 || decimal.Truncate(model.TicketFee) != model.TicketFee)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Bilet ücreti 1 ile 99999 arasında bir tam sayı olmalıdır.";
            return RedirectToAction(nameof(TicketSales));
        }

        var ticket = await context.JuryGameTicketFees.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (ticket is null) return NotFound();
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        var oldValue = ticket.TicketFee;
        if (oldValue == model.TicketFee)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Bilet ücreti mevcut değerle aynı olamaz.";
            return RedirectToAction(nameof(TicketSales));
        }

        ticket.TicketFee = model.TicketFee;
        ticket.UpdatedAt = TurkeyTime.Now;
        ticket.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Bilet ücreti başarıyla güncellendi.";
        return RedirectToAction(nameof(TicketSales));
    }

    [HttpGet("oyun-tarihleri")]
    public IActionResult PlayDates() => Page("Oyun Tarihleri", "Oyun gösterim tarihlerini yönetin.");

    [HttpGet("basvurular")]
    public async Task<IActionResult> Applications(CancellationToken cancellationToken)
    {
        var report = await applicationReportService.GetPageAsync(new ApplicationTableQuery(), cancellationToken);
        return View(new ApplicationsViewModel { Table = ApplicationComplexTableFactory.Create(report) });
    }

    [HttpPost("basvurular/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ApplicationsTable([FromForm] ApplicationTableQuery query, CancellationToken cancellationToken)
    {
        var report = await applicationReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = ApplicationComplexTableFactory.Create(report) });
    }

    [HttpGet("basvurular/{id:guid}")]
    public async Task<IActionResult> ApplicationDetails(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Forms.AsNoTracking()
            .Where(form => form.Id == id && form.IsPublished)
            .Select(form => new ApplicationDetailsViewModel
            {
                Id = form.Id,
                ApplicationNumber = form.ApplicationNumber,
                PlayName = form.RepertoireName,
                TheatreName = form.TheatreName,
                ApplicantName = form.ApplicantName,
                ApplicantRole = form.ApplicantRole,
                Email = form.Email,
                Phone = form.Phone,
                ContactName = form.ContactName,
                ContactPhone = form.ContactPhone,
                PremiereDate = form.PremiereDate,
                IsActive = form.IsActive
            })
            .SingleOrDefaultAsync(cancellationToken);
        return model is null ? NotFound() : View(model);
    }

    [AdminMutationAudit]
    [HttpPost("basvurular/{id:guid}/status")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateApplicationStatus(Guid id, [FromForm] bool isActive, CancellationToken cancellationToken)
    {
        var form = await context.Forms.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (form is null) return NotFound(new { message = "Başvuru bulunamadı." });

        form.IsActive = isActive;
        form.UpdatedDate = TurkeyTime.Now;
        await context.SaveChangesAsync(cancellationToken);
        return Ok(new { isActive = form.IsActive, refreshTable = false });
    }

    [AdminMutationAudit]
    [HttpPost("basvurular/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteApplication(Guid id, CancellationToken cancellationToken)
    {
        var form = await context.Forms.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (form is null) return NotFound(new { message = "Başvuru bulunamadı." });

        form.IsPublished = false;
        form.UpdatedDate = TurkeyTime.Now;
        await context.SaveChangesAsync(cancellationToken);

        if (string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase))
        {
            return Ok(new { success = true, refreshTable = true, message = "Başvuru başarıyla silindi." });
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Başvuru başarıyla silindi.";
        return RedirectToAction(nameof(Applications));
    }

    [HttpGet("basvurular/{id:guid}/duzenle")]
    public async Task<IActionResult> EditApplication(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Forms.AsNoTracking()
            .Where(form => form.Id == id && form.IsPublished)
            .Select(form => new EditApplicationViewModel
            {
                Id = form.Id,
                ApplicationNumber = form.ApplicationNumber,
                IsActive = form.IsActive,
                PlayName = form.RepertoireName,
                TheatreName = form.TheatreName,
                PremiereDate = form.PremiereDate,
                ApplicantName = form.ApplicantName,
                ApplicantRole = form.ApplicantRole,
                Phone = form.Phone,
                Email = form.Email,
                ContactName = form.ContactName,
                ContactPhone = form.ContactPhone
            })
            .SingleOrDefaultAsync(cancellationToken);
        return model is null ? NotFound() : View(model);
    }

    [AdminMutationAudit]
    [HttpPost("basvurular/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditApplication(Guid id, EditApplicationViewModel model, CancellationToken cancellationToken)
    {
        if (id != model.Id) return BadRequest();
        NormalizeApplication(model);

        if (await context.Forms.AsNoTracking().AnyAsync(form =>
                form.Id != id && form.IsPublished && form.ApplicationNumber == model.ApplicationNumber,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.ApplicationNumber), "Bu başvuru numarası başka bir aktif kayıtta kullanılıyor.");
        }

        var form = await context.Forms.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (form is null) return NotFound();

        if (!ModelState.IsValid || !model.PremiereDate.HasValue)
        {
            TempData["GenericPopup.Type"] = "fail";
            var validationMessage = string.Join("\n",
                ModelState.Values.SelectMany(value => value.Errors)
                    .Select(error => error.ErrorMessage)
                    .Where(message => !string.IsNullOrWhiteSpace(message))
                    .Distinct());
            TempData["GenericPopup.Message"] = string.IsNullOrWhiteSpace(validationMessage)
                ? "Form alanlarını kontrol ediniz."
                : validationMessage;
            return View(model);
        }

        var hasChanges = form.ApplicationNumber != model.ApplicationNumber ||
            form.IsActive != model.IsActive!.Value ||
            form.RepertoireName != model.PlayName ||
            form.TheatreName != model.TheatreName ||
            form.PremiereDate != model.PremiereDate.Value ||
            form.ApplicantName != model.ApplicantName ||
            form.ApplicantRole != model.ApplicantRole ||
            form.Phone != model.Phone ||
            form.Email != model.Email ||
            (form.ContactName ?? string.Empty) != (model.ContactName ?? string.Empty) ||
            (form.ContactPhone ?? string.Empty) != (model.ContactPhone ?? string.Empty);
        if (!hasChanges)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Herhangi bir değişiklik yapmadınız.";
            return View(model);
        }

        form.ApplicationNumber = model.ApplicationNumber;
        form.IsActive = model.IsActive!.Value;
        form.RepertoireName = model.PlayName;
        form.TheatreName = model.TheatreName;
        form.PremiereDate = model.PremiereDate.Value;
        form.ApplicantName = model.ApplicantName;
        form.ApplicantRole = model.ApplicantRole;
        form.Phone = model.Phone;
        form.Email = model.Email;
        form.ContactName = model.ContactName;
        form.ContactPhone = model.ContactPhone;
        form.UpdatedDate = TurkeyTime.Now;
        await context.SaveChangesAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Başvuru başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(ApplicationDetails), new { id });
        return RedirectToAction(nameof(EditApplication), new { id });
    }

    private static void NormalizeApplication(EditApplicationViewModel model)
    {
        model.ApplicationNumber = model.ApplicationNumber?.Trim() ?? string.Empty;
        model.PlayName = model.PlayName?.Trim() ?? string.Empty;
        model.TheatreName = model.TheatreName?.Trim() ?? string.Empty;
        model.ApplicantName = model.ApplicantName?.Trim() ?? string.Empty;
        model.ApplicantRole = model.ApplicantRole?.Trim() ?? string.Empty;
        model.Phone = model.Phone?.Trim() ?? string.Empty;
        model.Email = model.Email?.Trim() ?? string.Empty;
        model.ContactName = string.IsNullOrWhiteSpace(model.ContactName) ? null : model.ContactName.Trim();
        model.ContactPhone = string.IsNullOrWhiteSpace(model.ContactPhone) ? null : model.ContactPhone.Trim();
    }

    [HttpGet("blacklists")]
    public async Task<IActionResult> Blacklists(CancellationToken cancellationToken)
    {
        var report = await blacklistReportService.GetPageAsync(new BlacklistTableQuery(), cancellationToken);
        return View(new BlacklistViewModel { Table = BlacklistComplexTableFactory.Create(report) });
    }

    [HttpPost("blacklists/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> BlacklistTable([FromForm] BlacklistTableQuery query, CancellationToken cancellationToken)
    {
        var report = await blacklistReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = BlacklistComplexTableFactory.Create(report) });
    }

    [HttpPost("blacklists/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportBlacklists([FromForm] BlacklistTableQuery query, CancellationToken cancellationToken)
    {
        var rows = await blacklistReportService.GetExportRowsAsync(query, cancellationToken);
        var content = excelExporter.Export(BlacklistExcelExportFactory.Create(rows, query));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"blacklists-{DateTime.Today:yyyy-MM-dd}.xlsx");
    }

    [HttpGet("blacklists/ekle")]
    public async Task<IActionResult> AddBlacklist(CancellationToken cancellationToken)
    {
        var model = new AddBlacklistViewModel
        {
            JuryId = Guid.TryParse(TempData["Blacklist.JuryId"]?.ToString(), out var juryId) ? juryId : null,
            PlayId = Guid.TryParse(TempData["Blacklist.PlayId"]?.ToString(), out var playId) ? playId : null
        };
        await PopulateBlacklistSelectionAsync(model, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("blacklists/ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddBlacklist(AddBlacklistViewModel model, CancellationToken cancellationToken)
    {
        if (!model.JuryId.HasValue || !await context.Users.AsNoTracking().AnyAsync(
                user => user.Id == model.JuryId.Value && user.IsPublished && user.IsActive && user.RoleCode == 2,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.JuryId), "Geçerli bir jüri seçiniz.");
        }

        if (!model.PlayId.HasValue || !await context.Plays.AsNoTracking().AnyAsync(
                play => play.Id == model.PlayId.Value && play.IsPublished && !play.RecordType,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.PlayId), "Geçerli bir oyun seçiniz.");
        }

        if (model.JuryId.HasValue && model.PlayId.HasValue && await context.Blacklists.AsNoTracking().AnyAsync(
                item => item.JuryId == model.JuryId.Value && item.PlayId == model.PlayId.Value && item.IsPublished,
                cancellationToken))
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Bu jüri ve oyun için aktif bir blacklist kaydı zaten bulunuyor.";
            TempData["Blacklist.JuryId"] = model.JuryId.Value.ToString();
            TempData["Blacklist.PlayId"] = model.PlayId.Value.ToString();
            return RedirectToAction(nameof(AddBlacklist));
        }

        if (!ModelState.IsValid)
        {
            await PopulateBlacklistSelectionAsync(model, cancellationToken);
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();
        var id = Guid.NewGuid();
        context.Blacklists.Add(new Models.Entities.Blacklist
        {
            Id = id,
            JuryId = model.JuryId!.Value,
            PlayId = model.PlayId!.Value,
            CreatedBy = currentUserId,
            CreatedOn = TurkeyTime.Now,
            IsPublished = true
        });
        await context.SaveChangesAsync(cancellationToken);


        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Blacklist kaydı başarıyla eklendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Blacklists)) ?? "/blacklists";
        return RedirectToAction(nameof(AddBlacklist));
    }

    [AdminMutationAudit]
    [HttpPost("blacklists/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteBlacklist(Guid id, CancellationToken cancellationToken)
    {
        var blacklist = await context.Blacklists.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (blacklist is null) return NotFound();
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        blacklist.IsPublished = false;
        await context.SaveChangesAsync(cancellationToken);


        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Blacklist kaydı başarıyla silindi.";
        return RedirectToAction(nameof(Blacklists));
    }

    [HttpGet("diger-ayarlar")]
    public async Task<IActionResult> VotingSettings(CancellationToken cancellationToken)
    {
        var seasonReport = await seasonSettingsReportService.GetPageAsync(
            new SeasonSettingsTableQuery(), cancellationToken);
        var additionalVotingReport = await additionalVotingReportService.GetPageAsync(
            new AdditionalVotingTableQuery(), cancellationToken);
        var playStatuses = await context.PlayStatuses.AsNoTracking()
            .Where(status => status.IsPublished)
            .OrderBy(status => status.StatusCode)
            .Select(status => new PlayStatusSettingsRowViewModel
            {
                Id = status.Id,
                StatusCode = status.StatusCode,
                StatusName = status.StatusName,
                StatusColor = status.StatusColor ?? "#6B7280"
            })
            .ToArrayAsync(cancellationToken);
        var announcements = await context.Announcements.AsNoTracking()
            .Where(item => item.IsPublished)
            .OrderBy(item => item.AnnouncementLocationId)
            .ThenBy(item => item.CreatedAt)
            .Select(item => new AnnouncementSettingsRowViewModel
            {
                Id = item.Id,
                AnnouncementLocationId = item.AnnouncementLocationId,
                Text = item.Text ?? string.Empty
            })
            .ToArrayAsync(cancellationToken);
        var juryHomePageConfigNames = JuryHomePageTableSettings.Definitions
            .Select(definition => definition.Name)
            .ToArray();
        var juryHomePageConfigs = await context.Configs.AsNoTracking()
            .Where(item => item.IsPublished && juryHomePageConfigNames.Contains(item.ConfigName))
            .ToDictionaryAsync(item => item.ConfigName, item => item.ConfigValue, cancellationToken);
        var juryHomePageTables = JuryHomePageTableSettings.Definitions
            .Select(definition => new JuryHomePageTableSettingsRowViewModel
            {
                ConfigName = definition.Name,
                Title = definition.Title,
                IsAvailable = juryHomePageConfigs.ContainsKey(definition.Name),
                IsEnabled = JuryHomePageTableSettings.IsEnabled(
                    juryHomePageConfigs.GetValueOrDefault(definition.Name))
            })
            .ToArray();
        return View(new VotingSettingsViewModel
        {
            SeasonTable = SeasonSettingsComplexTableFactory.Create(seasonReport),
            AdditionalVotingTable = AdditionalVotingComplexTableFactory.Create(additionalVotingReport),
            PlayStatusTable = PlayStatusSettingsComplexTableFactory.Create(playStatuses),
            AnnouncementTable = AnnouncementSettingsComplexTableFactory.Create(announcements),
            JuryHomePageTable = JuryHomePageTableSettingsComplexTableFactory.Create(juryHomePageTables)
        });
    }

    [HttpGet("diger-ayarlar/oyun-statuler/{id:guid}")]
    public async Task<IActionResult> PlayStatusDetails(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.PlayStatuses.AsNoTracking()
            .Where(status => status.Id == id && status.IsPublished)
            .Select(status => new PlayStatusDetailsViewModel
            {
                Id = status.Id,
                StatusCode = status.StatusCode,
                StatusName = status.StatusName,
                StatusColor = status.StatusColor ?? "#6B7280"
            })
            .SingleOrDefaultAsync(cancellationToken);

        return model is null ? NotFound() : View(model);
    }

    [HttpGet("diger-ayarlar/oyun-statuler/{id:guid}/duzenle")]
    public async Task<IActionResult> EditPlayStatus(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.PlayStatuses.AsNoTracking()
            .Where(status => status.Id == id && status.IsPublished)
            .Select(status => new EditPlayStatusViewModel
            {
                Id = status.Id,
                StatusCode = status.StatusCode,
                StatusName = status.StatusName,
                StatusColor = status.StatusColor ?? "#6B7280"
            })
            .SingleOrDefaultAsync(cancellationToken);

        return model is null ? NotFound() : View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/oyun-statuler/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditPlayStatus(
        Guid id,
        EditPlayStatusViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.Id != id) return BadRequest();

        var status = await context.PlayStatuses.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (status is null) return NotFound();

        model.StatusCode = status.StatusCode;
        model.StatusName = status.StatusName;
        model.StatusColor = model.StatusColor?.Trim() ?? string.Empty;
        if (!ModelState.IsValid)
        {
            SetPlayStatusValidationPopup();
            return View(model);
        }

        if (string.Equals(status.StatusColor, model.StatusColor, StringComparison.OrdinalIgnoreCase))
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Herhangi bir değişiklik yapmadınız.";
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        status.StatusColor = model.StatusColor.ToUpperInvariant();
        status.UpdatedAt = TurkeyTime.Now;
        status.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Oyun statüsü rengi başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(PlayStatusDetails), new { id });
        return RedirectToAction(nameof(EditPlayStatus), new { id });
    }

    private void SetPlayStatusValidationPopup()
    {
        var message = string.Join("\n", ModelState.Values
            .SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage)
            .Where(error => !string.IsNullOrWhiteSpace(error))
            .Distinct());
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = string.IsNullOrWhiteSpace(message)
            ? "Renk kodunu kontrol ediniz."
            : message;
    }

    [HttpPost("diger-ayarlar/sezonlar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SeasonSettingsTable(
        [FromForm] SeasonSettingsTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await seasonSettingsReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new
        {
            model = SeasonSettingsComplexTableFactory.Create(report)
        });
    }

    [HttpGet("diger-ayarlar/sezon-ekle")]
    public async Task<IActionResult> AddSeason(CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(TurkeyTime.Now);
        var model = new SeasonFormViewModel
        {
            SeasonStartDate = today,
            KunyeRegistrationStartDate = today,
            KunyeRegistrationEndDate = today,
            VotingStartDate = today,
            VotingEndDate = today,
            SeasonEndDate = today
        };
        model.OtherPublishedSeasons = await GetPublishedSeasonRangesAsync(null, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/sezon-ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddSeason(SeasonFormViewModel model, CancellationToken cancellationToken)
    {
        await ValidateSeasonAvailabilityAsync(model, null, cancellationToken);
        if (!ModelState.IsValid)
        {
            SetSeasonValidationPopup();
            return View(model);
        }

        context.Seasons.Add(new Season
        {
            Id = Guid.NewGuid(),
            SeasonStartDate = model.SeasonStartDate!.Value,
            KunyeRegistrationStartDate = model.KunyeRegistrationStartDate!.Value,
            KunyeRegistrationEndDate = model.KunyeRegistrationEndDate!.Value,
            VotingStartDate = model.VotingStartDate!.Value,
            VotingEndDate = model.VotingEndDate!.Value,
            SeasonEndDate = model.SeasonEndDate!.Value,
            PlayCount = 0,
            ActivePlayCount = 0,
            VoteCount = 0,
            IsPublished = true
        });

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception)
        {
            logger.LogWarning(exception, "Sezon kaydı oluşturulamadı.");
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Sezon kaydı oluşturulamadı. Tarih aralıklarını ve çakışan sezonları kontrol ediniz.";
            return View(model);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Sezon başarıyla eklendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(VotingSettings));
        return RedirectToAction(nameof(AddSeason));
    }

    [HttpGet("diger-ayarlar/sezonlar/{id:guid}")]
    public async Task<IActionResult> SeasonDetails(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Seasons.AsNoTracking()
            .Where(season => season.Id == id && season.IsPublished)
            .Select(season => new SeasonDetailsViewModel
            {
                Id = season.Id,
                SeasonStartDate = season.SeasonStartDate,
                KunyeRegistrationStartDate = season.KunyeRegistrationStartDate,
                KunyeRegistrationEndDate = season.KunyeRegistrationEndDate,
                VotingStartDate = season.VotingStartDate,
                VotingEndDate = season.VotingEndDate,
                SeasonEndDate = season.SeasonEndDate
            })
            .SingleOrDefaultAsync(cancellationToken);
        return model is null ? NotFound() : View(model);
    }

    [HttpGet("diger-ayarlar/sezonlar/{id:guid}/duzenle")]
    public async Task<IActionResult> EditSeason(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.Seasons.AsNoTracking()
            .Where(season => season.Id == id && season.IsPublished)
            .Select(season => new SeasonFormViewModel
            {
                Id = season.Id,
                SeasonStartDate = season.SeasonStartDate,
                KunyeRegistrationStartDate = season.KunyeRegistrationStartDate,
                KunyeRegistrationEndDate = season.KunyeRegistrationEndDate,
                VotingStartDate = season.VotingStartDate,
                VotingEndDate = season.VotingEndDate,
                SeasonEndDate = season.SeasonEndDate
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (model is null) return NotFound();

        model.OtherPublishedSeasons = await GetPublishedSeasonRangesAsync(id, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/sezonlar/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditSeason(
        Guid id,
        SeasonFormViewModel model,
        CancellationToken cancellationToken)
    {
        if (model.Id != id) return BadRequest();
        await ValidateSeasonAvailabilityAsync(model, id, cancellationToken);

        var season = await context.Seasons.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (season is null) return NotFound();

        if (!ModelState.IsValid)
        {
            SetSeasonValidationPopup();
            return View(model);
        }

        var hasChanges = season.SeasonStartDate != model.SeasonStartDate!.Value ||
            season.KunyeRegistrationStartDate != model.KunyeRegistrationStartDate!.Value ||
            season.KunyeRegistrationEndDate != model.KunyeRegistrationEndDate!.Value ||
            season.VotingStartDate != model.VotingStartDate!.Value ||
            season.VotingEndDate != model.VotingEndDate!.Value ||
            season.SeasonEndDate != model.SeasonEndDate!.Value;
        if (!hasChanges)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Herhangi bir değişiklik yapmadınız.";
            return View(model);
        }

        season.SeasonStartDate = model.SeasonStartDate.Value;
        season.KunyeRegistrationStartDate = model.KunyeRegistrationStartDate!.Value;
        season.KunyeRegistrationEndDate = model.KunyeRegistrationEndDate!.Value;
        season.VotingStartDate = model.VotingStartDate!.Value;
        season.VotingEndDate = model.VotingEndDate!.Value;
        season.SeasonEndDate = model.SeasonEndDate!.Value;

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception)
        {
            logger.LogWarning(exception, "{SeasonId} sezon kaydı güncellenemedi.", id);
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Sezon güncellenemedi. Tarih aralıklarını ve çakışan sezonları kontrol ediniz.";
            return View(model);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Sezon başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(SeasonDetails), new { id });
        return RedirectToAction(nameof(EditSeason), new { id });
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/sezonlar/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteSeason(Guid id, CancellationToken cancellationToken)
    {
        var season = await context.Seasons.SingleOrDefaultAsync(
            item => item.Id == id && item.IsPublished,
            cancellationToken);
        if (season is null) return NotFound();

        season.IsPublished = false;
        await context.SaveChangesAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Sezon başarıyla silindi.";
        return RedirectToAction(nameof(VotingSettings));
    }

    private async Task ValidateSeasonAvailabilityAsync(
        SeasonFormViewModel model,
        Guid? excludedId,
        CancellationToken cancellationToken)
    {
        model.OtherPublishedSeasons = await GetPublishedSeasonRangesAsync(excludedId, cancellationToken);
        if (!model.SeasonStartDate.HasValue || !model.SeasonEndDate.HasValue ||
            model.SeasonStartDate.Value >= model.SeasonEndDate.Value)
        {
            return;
        }

        var conflict = model.OtherPublishedSeasons.FirstOrDefault(season =>
            model.SeasonStartDate.Value <= season.SeasonEndDate &&
            model.SeasonEndDate.Value >= season.SeasonStartDate);
        if (conflict is null) return;

        var exactRange = model.SeasonStartDate.Value == conflict.SeasonStartDate &&
            model.SeasonEndDate.Value == conflict.SeasonEndDate;
        ModelState.AddModelError(string.Empty, exactRange
            ? $"{conflict.SeasonName} sezonuyla aynı başlangıç ve bitiş tarihleri kullanılamaz."
            : $"Sezon tarihleri {conflict.SeasonName} sezonuyla çakışıyor. Sezonlar ortak tarihe sahip olamaz.");
    }

    private async Task<IReadOnlyList<SeasonDateRangeViewModel>> GetPublishedSeasonRangesAsync(
        Guid? excludedId,
        CancellationToken cancellationToken) => await context.Seasons.AsNoTracking()
            .Where(season => season.IsPublished && (!excludedId.HasValue || season.Id != excludedId.Value))
            .OrderBy(season => season.SeasonStartDate)
            .Select(season => new SeasonDateRangeViewModel
            {
                Id = season.Id,
                SeasonStartDate = season.SeasonStartDate,
                SeasonEndDate = season.SeasonEndDate
            })
            .ToArrayAsync(cancellationToken);

    private void SetSeasonValidationPopup()
    {
        var message = string.Join("\n", ModelState.Values
            .SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage)
            .Where(error => !string.IsNullOrWhiteSpace(error))
            .Distinct());
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = string.IsNullOrWhiteSpace(message)
            ? "Sezon tarihlerini kontrol ediniz."
            : message;
    }

    [HttpPost("diger-ayarlar/ek-oylamalar/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AdditionalVotingTable(
        [FromForm] AdditionalVotingTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await additionalVotingReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new { model = AdditionalVotingComplexTableFactory.Create(report) });
    }

    [HttpGet("diger-ayarlar/ek-oylama-ekle")]
    public async Task<IActionResult> AddAdditionalVoting(CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(TurkeyTime.Now);
        var model = new AdditionalVotingFormViewModel { StartDate = today, EndDate = today.AddDays(1) };
        await PopulateAdditionalVotingOptionsAsync(model, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/ek-oylama-ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddAdditionalVoting(AdditionalVotingFormViewModel model, CancellationToken cancellationToken)
    {
        var selection = await ValidateAdditionalVotingSelectionAsync(model, cancellationToken);
        if (!ModelState.IsValid)
        {
            SetAdditionalVotingValidationPopup();
            await PopulateAdditionalVotingOptionsAsync(model, cancellationToken);
            return View(model);
        }
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        var now = TurkeyTime.Now;
        var record = new AdditionalVoting
        {
            Id = Guid.NewGuid(), StartDate = model.StartDate!.Value, EndDate = model.EndDate!.Value,
            AppliesToAllJuries = model.AppliesToAllJuries, AppliesToAllPlays = model.AppliesToAllPlays,
            CreatedAt = now, CreatedBy = currentUserId, IsActive = true, IsPublished = true
        };
        context.AdditionalVotings.Add(record);
        AddAdditionalVotingLinks(record.Id, selection.JuryIds, selection.PlayIds, currentUserId, now);
        await context.SaveChangesAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Ek oylama hakkı başarıyla oluşturuldu.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(AdditionalVotingDetails), new { id = record.Id });
        return RedirectToAction(nameof(AddAdditionalVoting));
    }

    [HttpGet("diger-ayarlar/ek-oylamalar/{id:guid}")]
    public async Task<IActionResult> AdditionalVotingDetails(Guid id, CancellationToken cancellationToken)
    {
        var record = await context.AdditionalVotings.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished)
            .Select(item => new { item.Id, item.StartDate, item.EndDate, item.AppliesToAllJuries, item.AppliesToAllPlays })
            .SingleOrDefaultAsync(cancellationToken);
        if (record is null) return NotFound();

        var juryNames = record.AppliesToAllJuries
            ? []
            : await GetAdditionalVotingJuryLabelsAsync(id, cancellationToken);
        var playNames = record.AppliesToAllPlays ? [] : await context.AdditionalVotingPlays.AsNoTracking()
            .Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .OrderBy(link => link.Play.PlayName).Select(link => link.Play.PlayName).ToArrayAsync(cancellationToken);
        var firstVoteUsers = await GetAdditionalVotingUsageNamesAsync(id, AdditionalVotingUsageType.FirstVote, cancellationToken);
        var updateUsers = await GetAdditionalVotingUsageNamesAsync(id, AdditionalVotingUsageType.VoteUpdate, cancellationToken);

        return View(new AdditionalVotingDetailsViewModel
        {
            Id = record.Id, StartDate = record.StartDate, EndDate = record.EndDate,
            AppliesToAllJuries = record.AppliesToAllJuries, AppliesToAllPlays = record.AppliesToAllPlays,
            JuryNames = juryNames, PlayNames = playNames,
            FirstVoteUserNames = firstVoteUsers, VoteUpdateUserNames = updateUsers
        });
    }

    [HttpGet("diger-ayarlar/ek-oylamalar/{id:guid}/duzenle")]
    public async Task<IActionResult> EditAdditionalVoting(Guid id, CancellationToken cancellationToken)
    {
        var model = await context.AdditionalVotings.AsNoTracking()
            .Where(item => item.Id == id && item.IsPublished)
            .Select(item => new AdditionalVotingFormViewModel
            {
                Id = item.Id, StartDate = item.StartDate, EndDate = item.EndDate,
                AppliesToAllJuries = item.AppliesToAllJuries, AppliesToAllPlays = item.AppliesToAllPlays
            }).SingleOrDefaultAsync(cancellationToken);
        if (model is null) return NotFound();
        model.SelectedJuryIds = await context.AdditionalVotingJuries.AsNoTracking()
            .Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive).Select(link => link.JuryId).ToListAsync(cancellationToken);
        model.SelectedPlayIds = await context.AdditionalVotingPlays.AsNoTracking()
            .Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive).Select(link => link.PlayId).ToListAsync(cancellationToken);
        await PopulateAdditionalVotingOptionsAsync(model, cancellationToken);
        return View(model);
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/ek-oylamalar/{id:guid}/duzenle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditAdditionalVoting(Guid id, AdditionalVotingFormViewModel model, CancellationToken cancellationToken)
    {
        if (model.Id != id) return BadRequest();
        var selection = await ValidateAdditionalVotingSelectionAsync(model, cancellationToken);
        var record = await context.AdditionalVotings.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (record is null) return NotFound();
        if (!ModelState.IsValid)
        {
            SetAdditionalVotingValidationPopup();
            await PopulateAdditionalVotingOptionsAsync(model, cancellationToken);
            return View(model);
        }
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        var currentJuries = await context.AdditionalVotingJuries.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .Select(link => link.JuryId).OrderBy(value => value).ToArrayAsync(cancellationToken);
        var currentPlays = await context.AdditionalVotingPlays.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .Select(link => link.PlayId).OrderBy(value => value).ToArrayAsync(cancellationToken);
        var hasChanges = record.StartDate != model.StartDate!.Value || record.EndDate != model.EndDate!.Value ||
            record.AppliesToAllJuries != model.AppliesToAllJuries || record.AppliesToAllPlays != model.AppliesToAllPlays ||
            !currentJuries.SequenceEqual(selection.JuryIds.OrderBy(value => value)) ||
            !currentPlays.SequenceEqual(selection.PlayIds.OrderBy(value => value));
        if (!hasChanges)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Herhangi bir değişiklik yapmadınız.";
            await PopulateAdditionalVotingOptionsAsync(model, cancellationToken);
            return View(model);
        }

        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        var now = TurkeyTime.Now;
        record.StartDate = model.StartDate!.Value; record.EndDate = model.EndDate!.Value;
        record.AppliesToAllJuries = model.AppliesToAllJuries; record.AppliesToAllPlays = model.AppliesToAllPlays;
        record.UpdatedAt = now; record.UpdatedBy = currentUserId;
        await context.AdditionalVotingJuries.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(link => link.IsActive, false).SetProperty(link => link.IsPublished, false)
                .SetProperty(link => link.UpdatedAt, now).SetProperty(link => link.UpdatedBy, currentUserId), cancellationToken);
        await context.AdditionalVotingPlays.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(link => link.IsActive, false).SetProperty(link => link.IsPublished, false)
                .SetProperty(link => link.UpdatedAt, now).SetProperty(link => link.UpdatedBy, currentUserId), cancellationToken);
        await context.SaveChangesAsync(cancellationToken);
        AddAdditionalVotingLinks(id, selection.JuryIds, selection.PlayIds, currentUserId, now);
        await context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Ek oylama hakkı başarıyla güncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(AdditionalVotingDetails), new { id });
        return RedirectToAction(nameof(EditAdditionalVoting), new { id });
    }

    [AdminMutationAudit]
    [HttpPost("diger-ayarlar/ek-oylamalar/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteAdditionalVoting(Guid id, CancellationToken cancellationToken)
    {
        var record = await context.AdditionalVotings.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (record is null) return NotFound();
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();
        var now = TurkeyTime.Now;
        record.IsActive = false; record.IsPublished = false; record.UpdatedAt = now; record.UpdatedBy = currentUserId;
        await context.AdditionalVotingJuries.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(link => link.IsActive, false).SetProperty(link => link.IsPublished, false).SetProperty(link => link.UpdatedAt, now).SetProperty(link => link.UpdatedBy, currentUserId), cancellationToken);
        await context.AdditionalVotingPlays.Where(link => link.AdditionalVotingId == id && link.IsPublished && link.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(link => link.IsActive, false).SetProperty(link => link.IsPublished, false).SetProperty(link => link.UpdatedAt, now).SetProperty(link => link.UpdatedBy, currentUserId), cancellationToken);
        await context.AdditionalVotingUsages.Where(usage => usage.AdditionalVotingId == id && usage.IsPublished)
            .ExecuteUpdateAsync(setters => setters.SetProperty(usage => usage.IsActive, false).SetProperty(usage => usage.IsPublished, false).SetProperty(usage => usage.UpdatedAt, now).SetProperty(usage => usage.UpdatedBy, currentUserId), cancellationToken);
        await context.SaveChangesAsync(cancellationToken);
        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Ek oylama hakkı başarıyla silindi.";
        return RedirectToAction(nameof(VotingSettings));
    }

    private async Task PopulateAdditionalVotingOptionsAsync(AdditionalVotingFormViewModel model, CancellationToken cancellationToken)
    {
        var holder = new AddPlayViewModel();
        await PopulateAddPlayOptionsAsync(holder, cancellationToken, includeActiveStatus: true);
        model.JuryGroups = holder.JuryGroups;
        model.PlayOptions = await context.Plays.AsNoTracking()
            .Where(play => play.IsPublished && play.IsActive && play.StatusCode == 1)
            .OrderBy(play => play.PlayName).ThenBy(play => play.TheaterName)
            .Select(play => new AdditionalVotingPlayOptionViewModel
            {
                Id = play.Id,
                Name = play.PlayName + " / " + play.TheaterName
            }).ToArrayAsync(cancellationToken);
    }

    private async Task<(Guid[] JuryIds, Guid[] PlayIds)> ValidateAdditionalVotingSelectionAsync(
        AdditionalVotingFormViewModel model, CancellationToken cancellationToken)
    {
        var juryIds = model.AppliesToAllJuries ? [] : model.SelectedJuryIds.Distinct().ToArray();
        var playIds = model.AppliesToAllPlays ? [] : model.SelectedPlayIds.Distinct().ToArray();
        if (!model.AppliesToAllJuries)
        {
            var validCount = await context.Users.CountAsync(user => juryIds.Contains(user.Id) && user.IsPublished && user.IsActive && user.RoleCode == 2, cancellationToken);
            if (validCount != juryIds.Length) ModelState.AddModelError(nameof(model.SelectedJuryIds), "Seçilen jürilerden biri artık uygun değil.");
        }
        if (!model.AppliesToAllPlays)
        {
            var validCount = await context.Plays.CountAsync(play => playIds.Contains(play.Id) && play.IsPublished && play.IsActive && play.StatusCode == 1, cancellationToken);
            if (validCount != playIds.Length) ModelState.AddModelError(nameof(model.SelectedPlayIds), "Seçilen oyunlardan biri artık uygun değil.");
        }
        return (juryIds, playIds);
    }

    private void AddAdditionalVotingLinks(Guid id, IEnumerable<Guid> juryIds, IEnumerable<Guid> playIds, Guid userId, DateTime now)
    {
        context.AdditionalVotingJuries.AddRange(juryIds.Select(juryId => new AdditionalVotingJury
        {
            Id = Guid.NewGuid(), AdditionalVotingId = id, JuryId = juryId,
            CreatedAt = now, CreatedBy = userId, IsActive = true, IsPublished = true
        }));
        context.AdditionalVotingPlays.AddRange(playIds.Select(playId => new AdditionalVotingPlay
        {
            Id = Guid.NewGuid(), AdditionalVotingId = id, PlayId = playId,
            CreatedAt = now, CreatedBy = userId, IsActive = true, IsPublished = true
        }));
    }

    private async Task<IReadOnlyList<string>> GetAdditionalVotingJuryLabelsAsync(
        Guid additionalVotingId,
        CancellationToken cancellationToken)
    {
        var selectedJuries = await context.AdditionalVotingJuries.AsNoTracking()
            .Where(link => link.AdditionalVotingId == additionalVotingId && link.IsPublished && link.IsActive)
            .Select(link => new
            {
                link.JuryId,
                link.Jury.GroupCode,
                FullName = (link.Jury.FirstName + " " + link.Jury.LastName).Trim()
            })
            .ToArrayAsync(cancellationToken);

        var groupCodes = selectedJuries
            .Where(jury => jury.GroupCode.HasValue)
            .Select(jury => jury.GroupCode!.Value)
            .Distinct()
            .ToArray();
        if (groupCodes.Length == 0)
        {
            return selectedJuries.OrderBy(jury => jury.FullName).Select(jury => jury.FullName).ToArray();
        }

        var eligibleGroupMembers = await context.Users.AsNoTracking()
            .Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2 &&
                user.GroupCode.HasValue && groupCodes.Contains(user.GroupCode.Value))
            .Select(user => new { user.Id, GroupCode = user.GroupCode!.Value })
            .ToArrayAsync(cancellationToken);
        var groupNames = await context.Groups.AsNoTracking()
            .Where(group => group.IsPublished && groupCodes.Contains(group.Code))
            .ToDictionaryAsync(group => group.Code, group => group.GroupName, cancellationToken);
        var selectedIds = selectedJuries.Select(jury => jury.JuryId).ToHashSet();
        var completeGroupCodes = eligibleGroupMembers
            .GroupBy(member => member.GroupCode)
            .Where(group => group.Any() && group.All(member => selectedIds.Contains(member.Id)) && groupNames.ContainsKey(group.Key))
            .Select(group => group.Key)
            .ToHashSet();

        return completeGroupCodes
            .Select(code => groupNames[code])
            .Concat(selectedJuries
                .Where(jury => !jury.GroupCode.HasValue || !completeGroupCodes.Contains(jury.GroupCode.Value))
                .Select(jury => jury.FullName))
            .OrderBy(label => label, StringComparer.Create(new System.Globalization.CultureInfo("tr-TR"), true))
            .ToArray();
    }
    private async Task<IReadOnlyList<string>> GetAdditionalVotingUsageNamesAsync(
        Guid id, AdditionalVotingUsageType usageType, CancellationToken cancellationToken) =>
        await context.AdditionalVotingUsages.AsNoTracking()
            .Where(usage => usage.AdditionalVotingId == id && usage.IsPublished && usage.IsActive && usage.UsageType == usageType)
            .Select(usage => new { usage.JuryId, Name = (usage.Jury.FirstName + " " + usage.Jury.LastName).Trim() })
            .Distinct().OrderBy(item => item.Name).Select(item => item.Name).ToArrayAsync(cancellationToken);

    private void SetAdditionalVotingValidationPopup()
    {
        var message = string.Join("\n", ModelState.Values.SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage).Where(error => !string.IsNullOrWhiteSpace(error)).Distinct());
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = string.IsNullOrWhiteSpace(message) ? "Ek oylama alanlarını kontrol ediniz." : message;
    }
    [HttpGet("arsiv-karsilastirma")]
    public async Task<IActionResult> ArchiveComparison(CancellationToken cancellationToken)
    {
        var report = await archiveComparisonReportService.GetPageAsync(
            new ArchiveComparisonTableQuery(),
            cancellationToken);
        return View(new ArchiveComparisonViewModel
        {
            Table = ArchiveComparisonComplexTableFactory.Create(report)
        });
    }

    [HttpPost("arsiv-karsilastirma/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ArchiveComparisonTable(
        [FromForm] ArchiveComparisonTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await archiveComparisonReportService.GetPageAsync(query, cancellationToken);
        return ViewComponent("ComplexTable", new
        {
            model = ArchiveComparisonComplexTableFactory.Create(report)
        });
    }
    private async Task<AddPlaySimilarityResult> GetAddPlaySimilarityAsync(
        string playName,
        string theaterName,
        CancellationToken cancellationToken,
        Guid? excludedPlayId = null)
    {
        var candidates = await context.Plays
            .AsNoTracking()
            .Where(play => !excludedPlayId.HasValue || play.Id != excludedPlayId.Value)
            .Select(play => new AddPlaySimilarityCandidate(
                play.Id,
                play.PlayName,
                play.TheaterName,
                play.Slug,
                play.IsPublished))
            .ToArrayAsync(cancellationToken);

        var hasExactMatch = candidates.Any(play => PlaySimilarityHelper.AreExactDuplicates(
            playName,
            theaterName,
            play.PlayName,
            play.TheaterName));
        if (hasExactMatch)
        {
            return new AddPlaySimilarityResult(true, []);
        }

        var similarPlays = candidates
            .Where(play => play.IsPublished && PlaySimilarityHelper.AreLikelyDuplicates(
                playName,
                theaterName,
                play.PlayName,
                play.TheaterName))
            .OrderBy(play => play.PlayName, StringComparer.Create(new System.Globalization.CultureInfo("tr-TR"), true))
            .ThenBy(play => play.Id)
            .ToArray();

        return new AddPlaySimilarityResult(false, similarPlays);
    }

    private async Task<IActionResult> ReturnAddPlayFailureAsync(
        AddPlayViewModel model,
        string message,
        CancellationToken cancellationToken)
    {
        model.ConfirmSimilarPlay = false;
        TempData["GenericPopup.Type"] = "fail";
        TempData["GenericPopup.Message"] = message;
        await PopulateAddPlayOptionsAsync(model, cancellationToken);
        return View(nameof(AddPlay), model);
    }

    private async Task PopulateAddPlayOptionsAsync(
        PlayFormViewModel model,
        CancellationToken cancellationToken,
        bool includeActiveStatus = false)
    {
        var statuses = await context.PlayStatuses
            .AsNoTracking()
            .Where(status => status.IsPublished && (includeActiveStatus || status.StatusCode != 1))
            .OrderBy(status => status.StatusCode)
            .Select(status => new
            {
                status.StatusCode,
                status.StatusName,
                status.StatusColor
            })
            .ToArrayAsync(cancellationToken);
        model.StatusOptions = statuses
            .Select(status => new AddPlayStatusOptionViewModel
            {
                StatusCode = status.StatusCode,
                StatusName = status.StatusName,
                StatusColor = NormalizeStatusColor(status.StatusColor)
            })
            .ToArray();

        var juries = await context.Users
            .AsNoTracking()
            .Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2)
            .OrderBy(user => user.FirstName)
            .ThenBy(user => user.LastName)
            .Select(user => new
            {
                user.Id,
                user.GroupCode,
                FullName = (user.FirstName + " " + user.LastName).Trim()
            })
            .ToArrayAsync(cancellationToken);

        var groupCodes = juries
            .Where(jury => jury.GroupCode.HasValue)
            .Select(jury => jury.GroupCode!.Value)
            .Distinct()
            .ToArray();
        var groupNames = await context.Groups
            .AsNoTracking()
            .Where(group => group.IsPublished && groupCodes.Contains(group.Code))
            .ToDictionaryAsync(group => group.Code, group => group.GroupName, cancellationToken);

        model.JuryGroups = juries
            .GroupBy(jury => jury.GroupCode.HasValue && groupNames.ContainsKey(jury.GroupCode.Value)
                ? jury.GroupCode.Value.ToString()
                : "ungrouped")
            .Select(group =>
            {
                var first = group.First();
                var name = first.GroupCode.HasValue && groupNames.TryGetValue(first.GroupCode.Value, out var groupName)
                    ? groupName
                    : "Grupsuz Jüriler";
                return new AddPlayJuryGroupViewModel
                {
                    Key = group.Key,
                    Name = name,
                    CanSelectAll = !string.Equals(group.Key, "ungrouped", StringComparison.Ordinal),
                    Juries = group
                        .Select(jury => new AddPlayJuryOptionViewModel
                        {
                            Id = jury.Id,
                            FullName = jury.FullName
                        })
                        .OrderBy(jury => jury.FullName)
                        .ToArray()
                };
            })
            .OrderBy(group => group.Name)
            .ToArray();
    }
    private async Task PopulateBlacklistSelectionAsync(AddBlacklistViewModel model, CancellationToken cancellationToken)
    {
        if (model.JuryId.HasValue)
        {
            model.JuryName = await context.Users
                .AsNoTracking()
                .Where(user => user.Id == model.JuryId.Value)
                .Select(user => (user.FirstName + " " + user.LastName).Trim())
                .SingleOrDefaultAsync(cancellationToken) ?? string.Empty;
        }
        if (model.PlayId.HasValue)
        {
            model.PlayName = await context.Plays
                .AsNoTracking()
                .Where(play => play.Id == model.PlayId.Value)
                .Select(play => play.PlayName)
                .SingleOrDefaultAsync(cancellationToken) ?? string.Empty;
        }
    }

    private static string FormatCandidateName(
        string candidate,
        string? role,
        bool includeCurrentState,
        bool isCurrent)
    {
        var roleText = string.IsNullOrWhiteSpace(role) ? string.Empty : $" / {role.Trim()}";
        var stateText = includeCurrentState ? (isCurrent ? " - Aktif Oyuncu" : " - Eski Oyuncu") : string.Empty;
        return $"{candidate.Trim()}{roleText}{stateText}";
    }
    private bool IsAjaxRequest() =>
        string.Equals(Request.Headers.XRequestedWith, "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);

    private string NormalizePlayReturnUrl(string? returnUrl) =>
        !string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl)
            ? returnUrl
            : "/oyunlar";

    private static string GetPlayReturnLabel(string returnUrl)
    {
        var path = returnUrl.Split('?', '#')[0].TrimEnd('/');

        if (path.Length == 0)
        {
            return "Ana Sayfaya Dön";
        }

        if (path.Equals("/juriler", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/juriler/", StringComparison.OrdinalIgnoreCase))
        {
            return "Jürilere Dön";
        }

        if (path.Equals("/oyunlar", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/oyunlar/", StringComparison.OrdinalIgnoreCase))
        {
            return "Oyunlara Dön";
        }

        return "Geri Dön";
    }
    private ViewResult Page(string title, string description) =>
        View("Page", new ManagementPageViewModel(title, description));

    private sealed record AddPlaySimilarityCandidate(
        Guid Id,
        string PlayName,
        string TheaterName,
        string Slug,
        bool IsPublished);

    private sealed record AddPlaySimilarityResult(
        bool HasExactMatch,
        IReadOnlyList<AddPlaySimilarityCandidate> SimilarPlays);
}
