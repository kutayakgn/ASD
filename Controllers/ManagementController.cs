using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;
using YKBAfife.Services.Audit;
using YKBAfife.Services.Exports;

namespace YKBAfife.Controllers;

public sealed class ManagementController(
    AfifeContext context,
    IJuryReportService juryReportService,
    IArchiveComparisonReportService archiveComparisonReportService,
    ITicketSalesReportService ticketSalesReportService,
    IBlacklistReportService blacklistReportService,
    IJuryWatchedPlayReportService juryWatchedPlayReportService,
    IPlayReportService playReportService,
    IUserActivityLogger activityLogger,
    IExcelExporter excelExporter) : Controller
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

        var document = JuryWatchedPlayExcelExportFactory.Create(report);
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
        jury.UpdatedAt = DateTime.UtcNow;
        jury.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.UserSoftDeleted,
            true,
            jury.Id,
            jury.Username,
            currentUserId,
            details: "J\u00fcri kayd\u0131 fiziksel olarak silinmeden yay\u0131ndan kald\u0131r\u0131ld\u0131.",
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "J\u00fcri ba\u015far\u0131yla silindi.";
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
                IsActive = user.IsActive
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
        model.Password = string.IsNullOrWhiteSpace(model.Password) ? null : model.Password;
        model.FullName = string.Join(
            ' ',
            (model.FullName ?? string.Empty).Split(
                (char[]?)null,
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        model.Phone = model.Phone?.Trim() ?? string.Empty;

        ModelState.Clear();
        TryValidateModel(model);

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Id != id && user.Username == model.Username,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Username), "Bu kullan\u0131c\u0131 ad\u0131 zaten kullan\u0131l\u0131yor.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Id != id && user.Email == model.Email,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Email), "Bu e-posta adresi zaten kullan\u0131l\u0131yor.");
        }

        byte[]? photoData = null;
        string? photoContentType = null;
        string? photoFileName = null;
        if (model.Photo is not null)
        {
            const long maximumPhotoSize = 5 * 1024 * 1024;
            if (model.Photo.Length == 0 || model.Photo.Length > maximumPhotoSize)
            {
                ModelState.AddModelError(nameof(model.Photo), "Foto\u011fraf boyutu 5 MB'dan k\u00fc\u00e7\u00fck olmal\u0131d\u0131r.");
            }
            else
            {
                await using var photoStream = new MemoryStream();
                await model.Photo.CopyToAsync(photoStream, cancellationToken);
                photoData = photoStream.ToArray();
                photoContentType = model.Photo.ContentType.Trim().ToLowerInvariant();
                photoFileName = Path.GetFileName(model.Photo.FileName);
                if (!IsSupportedPhoto(photoData, photoContentType))
                {
                    ModelState.AddModelError(
                        nameof(model.Photo),
                        "Yaln\u0131zca JPEG, PNG veya WebP format\u0131nda foto\u011fraf y\u00fckleyebilirsiniz.");
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

        var oldEmail = jury.Email;
        var passwordChanged = model.Password is not null;
        var fullNameParts = model.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        jury.FirstName = string.Join(' ', fullNameParts[..^1]);
        jury.LastName = fullNameParts[^1];
        jury.Username = model.Username;
        jury.Email = model.Email;
        jury.Phone = model.Phone;
        jury.IsActive = model.IsActive!.Value;
        jury.UpdatedAt = DateTime.UtcNow;
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
                CreatedAt = DateTime.UtcNow,
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
                oldPhoto.UpdatedAt = DateTime.UtcNow;
                oldPhoto.UpdatedBy = currentUserId;
            }
        }

        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.UserUpdated,
            true,
            jury.Id,
            jury.Username,
            currentUserId,
            details: "J\u00fcri kullan\u0131c\u0131 bilgileri g\u00fcncellendi.",
            cancellationToken: cancellationToken);

        if (!string.Equals(oldEmail, jury.Email, StringComparison.OrdinalIgnoreCase))
        {
            await activityLogger.LogAsync(
                UserActivityTypes.EmailChanged,
                true,
                jury.Id,
                jury.Username,
                currentUserId,
                details: "J\u00fcri e-posta adresi g\u00fcncellendi.",
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
                details: "J\u00fcri \u015fifresi y\u00f6netici taraf\u0131ndan de\u011fi\u015ftirildi.",
                cancellationToken: cancellationToken);
        }

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "J\u00fcri ba\u015far\u0131yla g\u00fcncellendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(JuryDetails), new { id }) ?? $"/juriler/{id}";
        return RedirectToAction(nameof(EditJury), new { id });
    }
    [HttpGet("juri-ekle")]
    public IActionResult AddJury() => View(new AddJuryViewModel());

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

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Username == model.Username,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Username), "Bu kullan\u0131c\u0131 ad\u0131 zaten kullan\u0131l\u0131yor.");
        }

        if (await context.Users.AsNoTracking().AnyAsync(
                user => user.Email == model.Email,
                cancellationToken))
        {
            ModelState.AddModelError(nameof(model.Email), "Bu e-posta adresi zaten kullan\u0131l\u0131yor.");
        }

        byte[]? photoData = null;
        string? photoContentType = null;
        string? photoFileName = null;

        if (model.Photo is not null)
        {
            const long maximumPhotoSize = 5 * 1024 * 1024;
            if (model.Photo.Length == 0 || model.Photo.Length > maximumPhotoSize)
            {
                ModelState.AddModelError(nameof(model.Photo), "Foto\u011Fraf boyutu 5 MB'dan k\u00FC\u00E7\u00FCk olmal\u0131d\u0131r.");
            }
            else
            {
                await using var photoStream = new MemoryStream();
                await model.Photo.CopyToAsync(photoStream, cancellationToken);
                photoData = photoStream.ToArray();
                photoContentType = model.Photo.ContentType.Trim().ToLowerInvariant();
                photoFileName = Path.GetFileName(model.Photo.FileName);

                if (!IsSupportedPhoto(photoData, photoContentType))
                {
                    ModelState.AddModelError(
                        nameof(model.Photo),
                        "Yaln\u0131zca JPEG, PNG veya WebP format\u0131nda foto\u011Fraf y\u00FCkleyebilirsiniz.");
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

        var fullNameParts = model.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var lastName = fullNameParts[^1];
        var firstName = string.Join(' ', fullNameParts[..^1]);
        var now = DateTime.UtcNow;
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
            RoleCode = 2
        });

        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.UserCreated,
            true,
            juryId,
            model.Username,
            currentUserId,
            details: "Yeni j\u00fcri kullan\u0131c\u0131s\u0131 olu\u015fturuldu.",
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "J\u00FCri ba\u015Far\u0131yla kaydedildi.";
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
    private static bool IsSupportedPhoto(byte[] data, string contentType)
    {
        if (contentType == "image/jpeg")
        {
            return data.Length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF;
        }

        if (contentType == "image/png")
        {
            byte[] signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
            return data.Length >= signature.Length && data.AsSpan(0, signature.Length).SequenceEqual(signature);
        }

        return contentType == "image/webp" &&
               data.Length >= 12 &&
               data.AsSpan(0, 4).SequenceEqual("RIFF"u8) &&
               data.AsSpan(8, 4).SequenceEqual("WEBP"u8);
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

    [HttpPost("oyunlar/{id:guid}/juri-oylama-status")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateJuryVotingStatus(
        Guid id,
        [FromForm] bool isActive,
        CancellationToken cancellationToken) =>
        UpdatePlayStatus(id, isActive, true, cancellationToken);

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

    [HttpPost("oyunlar/ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddPlay(
        AddPlayViewModel model,
        CancellationToken cancellationToken)
    {
        model.PlayName = model.PlayName?.Trim() ?? string.Empty;
        model.TheaterName = model.TheaterName?.Trim() ?? string.Empty;
        model.SelectedJuryIds = model.SelectedJuryIds?.Distinct().ToList() ?? [];

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
            await PopulateAddPlayOptionsAsync(model, cancellationToken);
            return View(model);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        var baseSlug = SlugHelper.Create(model.PlayName);
        var slug = baseSlug;
        var suffix = 2;
        while (await context.Plays.AsNoTracking().AnyAsync(play => play.Slug == slug, cancellationToken))
        {
            slug = $"{baseSlug}-{suffix++}";
        }

        var now = DateTime.UtcNow;
        var playId = Guid.NewGuid();
        await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
        var play = new Play
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
        };
        context.Plays.Add(play);

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

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Oyun başarıyla eklendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Plays)) ?? "/oyunlar";
        return RedirectToAction(nameof(AddPlay));
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

        if (play.RecordType)
        {
            var requiresNormalization = play.JuriOylamaStatus || play.KunyeGirisStatus;
            play.JuriOylamaStatus = false;
            play.KunyeGirisStatus = false;
            if (requiresNormalization)
            {
                play.UpdatedAt = DateTime.UtcNow;
                play.UpdatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var normalizingUserId)
                    ? normalizingUserId
                    : null;
                await context.SaveChangesAsync(cancellationToken);
            }

            return Json(new { isActive = false, isDisabled = true, refreshTable = requiresNormalization });
        }

        if (isJuryVotingStatus)
        {
            play.JuriOylamaStatus = isActive;
        }
        else
        {
            play.KunyeGirisStatus = isActive;
        }

        play.UpdatedAt = DateTime.UtcNow;
        play.UpdatedBy = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
            ? userId
            : null;
        await context.SaveChangesAsync(cancellationToken);

        return Json(new { isActive, refreshTable = true });
    }
    [HttpGet("oyunlar/{slug}")]
    public async Task<IActionResult> PlayDetails(string slug, CancellationToken cancellationToken)
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

        var groupNames = await (
            from assignment in context.JuryAssignedPlays.AsNoTracking()
            join user in context.Users.AsNoTracking()
                on assignment.JuryId equals user.Id
            join juryGroup in context.Groups.AsNoTracking()
                on user.GroupCode equals (int?)juryGroup.Code
            where assignment.PlayId == play.Id
               && assignment.IsPublished
               && juryGroup.IsPublished
            select juryGroup.GroupName)
            .Distinct()
            .OrderBy(groupName => groupName)
            .ToListAsync(cancellationToken);

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

        return View(new PlayDetailsViewModel
        {
            Id = play.Id,
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            JuriOylamaStatus = play.JuriOylamaStatus,
            JuryGroupInfo = groupNames.Count == 0 ? "-" : string.Join(", ", groupNames),
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
            Slug = SlugHelper.Resolve(play.Slug, play.PlayName)
        });
    }
    [HttpPost("oyunlar/{slug}/aday-ekle")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddCandidate(
        string slug,
        [Bind(Prefix = "Input")] AddCandidateInputModel input,
        CancellationToken cancellationToken)
    {
        var requestedPlayId = input.PlayId;
        var play = requestedPlayId.HasValue
            ? await context.Plays
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.Id == requestedPlayId.Value && item.IsPublished && !item.RecordType,
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

        if (!string.Equals(input.Mode, "new", StringComparison.Ordinal))
        {
            TempData["CandidateError"] = "Aday/Rol De\u011Fi\u015Fimi kay\u0131t ak\u0131\u015F\u0131 hen\u00FCz kullan\u0131ma a\u00E7\u0131k de\u011Fil.";
            return RedirectToCandidateSection(slug);
        }

        if (!input.AwardCategoryCode.HasValue ||
            !await context.AwardCategories.AsNoTracking().AnyAsync(
                category => category.IsPublished && category.CategoryCode == input.AwardCategoryCode.Value,
                cancellationToken))
        {
            TempData["CandidateError"] = "Ge\u00E7erli bir \u00F6d\u00FCl kategorisi se\u00E7iniz.";
            return RedirectToCandidateSection(slug);
        }

        if (input.Candidate.Length is < 2 or > 250 ||
            input.Role?.Length > 200 ||
            !input.IsPublished.HasValue)
        {
            TempData["CandidateError"] = "Ad\u0131 soyad\u0131 en az 2 karakter olmal\u0131 ve stat\u00FC se\u00E7ilmelidir.";
            return RedirectToCandidateSection(slug);
        }

        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Challenge();
        }

        await using var transaction = await context.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);

        var roleCode = 0;
        if (input.Role is not null)
        {
            var existingRoleCode = await context.PlayAwardCategories
                .Where(item => item.Role == input.Role)
                .Select(item => (int?)item.RoleCode)
                .FirstOrDefaultAsync(cancellationToken);

            roleCode = existingRoleCode ??
                (await context.PlayAwardCategories
                    .Select(item => (int?)item.RoleCode)
                    .MaxAsync(cancellationToken) ?? 0) + 1;
        }

        var duplicateExists = await context.PlayAwardCategories.AnyAsync(
            item => item.PlayId == play.Id &&
                    item.AwardCategoryCode == input.AwardCategoryCode.Value &&
                    item.RoleCode == roleCode &&
                    (item.Candidate == input.Candidate || item.IsCurrent),
            cancellationToken);

        if (duplicateExists)
        {
            await transaction.RollbackAsync(cancellationToken);
            TempData["CandidateError"] = "Bu aday zaten kay\u0131tl\u0131 veya ayn\u0131 rol i\u00E7in g\u00FCncel bir aday bulunuyor. Aday/Rol De\u011Fi\u015Fimi se\u00E7ene\u011Fini kullan\u0131n\u0131z.";
            return RedirectToCandidateSection(slug);
        }

        context.PlayAwardCategories.Add(new PlayAwardCategory
        {
            Id = Guid.NewGuid(),
            PlayId = play.Id,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = currentUserId,
            IsPublished = input.IsPublished.Value,
            Candidate = input.Candidate,
            AwardCategoryCode = input.AwardCategoryCode.Value,
            IsCurrent = true,
            Role = input.Role,
            RoleCode = roleCode,
        });

        await context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        TempData["CandidateSuccess"] = "Aday ba\u015Far\u0131yla eklendi.";
        return RedirectToCandidateSection(slug);
    }

    private IActionResult RedirectToCandidateSection(string slug)
    {
        var detailsUrl = Url.Action(nameof(PlayDetails), new { slug }) ?? $"/oyunlar/{slug}";
        return Redirect(detailsUrl + "#aday-ekle");
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
    public IActionResult Rankings() => Page(
        "Sıralamalar",
        "Oylama sonuçlarını ve kategori sıralamalarını inceleyin.");

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
    public IActionResult VotingHistory() => View(new VotingHistoryViewModel());

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
            return BadRequest(new { success = false, message = "S\u0131f\u0131rlanabilecek aktif bir oy bulunamad\u0131." });
        }
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Unauthorized(new { success = false, message = "Oturum bilgisi do\u011frulanamad\u0131." });
        }

        vote.IsPublished = false;
        vote.UpdatedAt = DateTime.UtcNow;
        vote.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.JuryVoteReset,
            true,
            juryId,
            actorUserId: currentUserId,
            details: $"J\u00fcri oyu s\u0131f\u0131rland\u0131. PlayId: {playId}, PlayAwardCategoryId: {playAwardCategoryId}",
            cancellationToken: cancellationToken);

        return Json(new { success = true, message = "Oylama ba\u015far\u0131yla s\u0131f\u0131rland\u0131." });
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
        var content = excelExporter.Export(TicketSalesExcelExportFactory.Create(rows));
        return File(content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"bilet-satislari-{DateTime.Today:yyyy-MM-dd}.xlsx");
    }

    [HttpGet("bilet-satislari/{id:guid}/duzenle")]
    public async Task<IActionResult> EditTicketFee(Guid id, CancellationToken cancellationToken)
    {
        var model = await ticketSalesReportService.GetEditModelAsync(id, cancellationToken);
        return model is null ? NotFound() : PartialView("_EditTicketFeeModal", model);
    }

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

        if (model.TicketFee < 1)
        {
            TempData["GenericPopup.Type"] = "fail";
            TempData["GenericPopup.Message"] = "Bilet ücreti 1'den az olamaz.";
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
        ticket.UpdatedAt = DateTime.UtcNow;
        ticket.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);

        await activityLogger.LogAsync(
            UserActivityTypes.TicketFeeChanged,
            true,
            ticket.UserId,
            actorUserId: currentUserId,
            details: "Jüri oyun bilet ücreti güncellendi.",
            oldValue: oldValue.ToString(System.Globalization.CultureInfo.InvariantCulture),
            newValue: ticket.TicketFee.ToString(System.Globalization.CultureInfo.InvariantCulture),
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Bilet ücreti başarıyla güncellendi.";
        return RedirectToAction(nameof(TicketSales));
    }

    [HttpGet("oyun-tarihleri")]
    public IActionResult PlayDates() => Page("Oyun Tarihleri", "Oyun gösterim tarihlerini yönetin.");

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
        var content = excelExporter.Export(BlacklistExcelExportFactory.Create(rows));
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
            CreatedOn = DateTime.UtcNow,
            IsPublished = true
        });
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.BlacklistCreated,
            true,
            model.JuryId,
            actorUserId: currentUserId,
            details: $"Blacklist kaydı oluşturuldu. PlayId: {model.PlayId}",
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Blacklist kaydı başarıyla eklendi.";
        TempData["GenericPopup.RedirectUrl"] = Url.Action(nameof(Blacklists)) ?? "/blacklists";
        return RedirectToAction(nameof(AddBlacklist));
    }

    [HttpPost("blacklists/{id:guid}/sil")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteBlacklist(Guid id, CancellationToken cancellationToken)
    {
        var blacklist = await context.Blacklists.SingleOrDefaultAsync(item => item.Id == id && item.IsPublished, cancellationToken);
        if (blacklist is null) return NotFound();
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId)) return Challenge();

        blacklist.IsPublished = false;
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.BlacklistSoftDeleted,
            true,
            blacklist.JuryId,
            actorUserId: currentUserId,
            details: $"Blacklist kaydı yayından kaldırıldı. PlayId: {blacklist.PlayId}",
            cancellationToken: cancellationToken);

        TempData["GenericPopup.Type"] = "success";
        TempData["GenericPopup.Message"] = "Blacklist kaydı başarıyla silindi.";
        return RedirectToAction(nameof(Blacklists));
    }

    [HttpGet("oylama-ayarlari")]
    public IActionResult VotingSettings() => Page("Oylama Ayarları", "Oylama dönemi ve puanlama ayarlarını yönetin.");

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
    private async Task PopulateAddPlayOptionsAsync(
        AddPlayViewModel model,
        CancellationToken cancellationToken)
    {
        var statuses = await context.PlayStatuses
            .AsNoTracking()
            .Where(status => status.IsPublished && status.StatusCode != 1)
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
        var roleText = string.IsNullOrWhiteSpace(role) ? string.Empty : $" ({role.Trim()})";
        var stateText = includeCurrentState ? (isCurrent ? " / Aktif Oyuncu" : " / Eski Oyuncu") : string.Empty;
        return $"{candidate.Trim()}{roleText}{stateText}";
    }
    private ViewResult Page(string title, string description) =>
        View("Page", new ManagementPageViewModel(title, description));
}
