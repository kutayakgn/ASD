using System.Data;
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
    ITicketSalesReportService ticketSalesReportService,
    IBlacklistReportService blacklistReportService,
    IJuryWatchedPlayReportService juryWatchedPlayReportService,
    IPlayReportService playReportService,
    ICandidateReportService candidateReportService,
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
        jury.UpdatedAt = TurkeyTime.Now;
        jury.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


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

        await context.SaveChangesAsync(cancellationToken);


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
            RoleCode = 2
        });

        await context.SaveChangesAsync(cancellationToken);


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
                message = "Aynı oyun adı ve tiyatro adına sahip bir oyun var. Yinelenen kayıt oluşturamazsınız."
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
                "Aynı oyun adı ve tiyatro adına sahip bir oyun var. Yinelenen kayıt oluşturamazsınız.",
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
                    "Aynı oyun adı ve tiyatro adına sahip bir oyun var. Yinelenen kayıt oluşturamazsınız.",
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
            JuriOylamaStatus = !play.RecordType && play.JuriOylamaStatus,
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
            return await ReturnEditPlayFailureAsync(model, "Oyun güncellenemedi. Lütfen zorunlu alanları kontrol ediniz.", cancellationToken);
        }

        var similarity = await GetAddPlaySimilarityAsync(
            model.PlayName, model.TheaterName, cancellationToken, play.Id);
        if (similarity.HasExactMatch)
        {
            return await ReturnEditPlayFailureAsync(model,
                "Aynı oyun adı ve tiyatro adına sahip başka bir oyun var. Yinelenen kayıt oluşturamazsınız.",
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
                    "Aynı oyun adı ve tiyatro adına sahip başka bir oyun var. Yinelenen kayıt oluşturamazsınız.",
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
            play.JuriOylamaStatus = !play.RecordType && model.JuriOylamaStatus;
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

        if (play.RecordType)
        {
            var requiresNormalization = play.JuriOylamaStatus || play.KunyeGirisStatus;
            play.JuriOylamaStatus = false;
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
        var kunyeRecords = context.Plays.Where(item =>
            item.Id == id &&
            item.IsPublished &&
            !item.RecordType);

        var updatedRowCount = isJuryVotingStatus
            ? await kunyeRecords.ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(item => item.JuriOylamaStatus, isActive)
                    .SetProperty(item => item.UpdatedAt, updatedAt)
                    .SetProperty(item => item.UpdatedBy, updatedBy),
                cancellationToken)
            : await kunyeRecords.ExecuteUpdateAsync(
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

        var juryGroupInfo = assignedJuries
            .Where(jury => jury.GroupCode.HasValue && assignedGroupNames.ContainsKey(jury.GroupCode.Value))
            .Select(jury => assignedGroupNames[jury.GroupCode!.Value])
            .Concat(assignedJuries
                .Where(jury => !jury.GroupCode.HasValue || !assignedGroupNames.ContainsKey(jury.GroupCode.Value))
                .Select(jury =>
                {
                    var fullName = $"{jury.FirstName} {jury.LastName}".Trim();
                    return string.IsNullOrWhiteSpace(fullName) ? jury.Username : fullName;
                }))
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
        return View(new PlayDetailsViewModel
        {
            Id = play.Id,
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            JuriOylamaStatus = !play.RecordType && play.JuriOylamaStatus,
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
            ReturnUrl = NormalizePlayReturnUrl(returnUrl),
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
        if (candidate.AwardCategoryCode == 1001)
        {
            return BadRequest(new
            {
                message = "Sistem tarafından yönetilen oyun kategorisinin statüsü değiştirilemez."
            });
        }

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
        if (candidate.AwardCategoryCode == 1001)
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
        var content = excelExporter.Export(CandidateExcelExportFactory.Create(play.PlayName, rows));
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
                            item.CategoryCode != 1001,
                    cancellationToken)
            : null;
        if (category is null)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Geçerli bir ödül kategorisi seçiniz.");
        }

        if (input.Candidate.Length is < 2 or > 250)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Adı Soyadı alanı 2 ile 250 karakter arasında olmalıdır.");
        }

        if (!input.IsActive.HasValue)
        {
            return RedirectToCandidateSectionWithPopup(slug, "fail", "Statü seçimi zorunludur.");
        }

        if (category.HasRoleAndPhoto && input.Role is null && !isChangeMode)
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
        if (category.HasRoleAndPhoto && input.Photo is not null)
        {
            const long maximumPhotoSize = 5 * 1024 * 1024;
            if (input.Photo.Length == 0 || input.Photo.Length > maximumPhotoSize)
            {
                return RedirectToCandidateSectionWithPopup(slug, "fail", "Fotoğraf boyutu 5 MB'dan küçük olmalıdır.");
            }

            await using var photoStream = new MemoryStream();
            await input.Photo.CopyToAsync(photoStream, cancellationToken);
            photoData = photoStream.ToArray();
            photoContentType = input.Photo.ContentType.Trim().ToLowerInvariant();
            photoFileName = Path.GetFileName(input.Photo.FileName);
            if (!IsSupportedPhoto(photoData, photoContentType))
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
                if (category.HasRoleAndPhoto && string.IsNullOrWhiteSpace(role))
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
                var roleAlreadyExists = publishedPlayCandidates.Any(item =>
                    candidateTextComparer.Equals(item.Role?.Trim(), role));
                if (roleAlreadyExists)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return RedirectToCandidateSectionWithPopup(
                        slug,
                        "fail",
                        RoleDuplicateMessage);
                }

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
                RoleCode = roleCode
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
            return BadRequest(new { success = false, message = "S\u0131f\u0131rlanabilecek bir oy bulunamad\u0131." });
        }
        if (!Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentUserId))
        {
            return Unauthorized(new { success = false, message = "Oturum bilgisi do\u011frulanamad\u0131." });
        }

        vote.IsPublished = false;
        vote.UpdatedAt = TurkeyTime.Now;
        vote.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


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
        ticket.UpdatedAt = TurkeyTime.Now;
        ticket.UpdatedBy = currentUserId;
        await context.SaveChangesAsync(cancellationToken);


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

    private static string NormalizePlayReturnUrl(string? returnUrl) =>
        string.Equals(returnUrl, "/", StringComparison.Ordinal) ? "/" : "/oyunlar";
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
