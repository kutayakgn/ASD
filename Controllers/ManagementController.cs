using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Reports;

namespace YKBAfife.Controllers;

public sealed class ManagementController(AfifeContext context, IJuryReportService juryReportService) : Controller
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

        context.Users.Add(new Models.Entities.User
        {
            Id = Guid.NewGuid(),
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
    public IActionResult Plays() => Page(
        "Oyunlar",
        "Oyun kayıtlarını ve oyun künyelerini yönetin.");

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
            FromKunye = play.FromKunye,
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
            !input.IsActive.HasValue)
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
            IsPublished = true,
            Candidate = input.Candidate,
            AwardCategoryCode = input.AwardCategoryCode.Value,
            IsCurrent = true,
            Role = input.Role,
            RoleCode = roleCode,
            IsActive = input.IsActive.Value
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

    [HttpGet("oylama-gecmisi")]
    public IActionResult VotingHistory() => Page("Oylama Geçmişi", "Geçmiş jüri oylarını inceleyin.");

    [HttpGet("bilet-satislari")]
    public IActionResult TicketSales() => Page("Bilet Satışları", "Oyun ve jüri bazlı bilet kayıtlarını yönetin.");

    [HttpGet("oyun-tarihleri")]
    public IActionResult PlayDates() => Page("Oyun Tarihleri", "Oyun gösterim tarihlerini yönetin.");

    [HttpGet("blacklists")]
    public IActionResult Blacklists() => Page("Blacklists", "Engellenen kayıtları ve nedenlerini yönetin.");

    [HttpGet("oylama-ayarlari")]
    public IActionResult VotingSettings() => Page("Oylama Ayarları", "Oylama dönemi ve puanlama ayarlarını yönetin.");

    [HttpGet("arsiv-karsilastirma")]
    public IActionResult ArchiveComparison() => Page("Arşiv Karşılaştırma", "Sezonlar arasındaki sonuçları karşılaştırın.");

    private ViewResult Page(string title, string description) =>
        View("Page", new ManagementPageViewModel(title, description));
}