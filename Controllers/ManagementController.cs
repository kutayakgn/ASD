using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Controllers;

public sealed class ManagementController(AfifeContext context) : Controller
{
    [HttpGet("sanata-sozumuz")]
    public IActionResult ArtPromise() => Page(
        "Sanata Sözümüz",
        "Afife'nin sanata verdiği sözü ve içeriklerini bu alandan yönetin.");

    [HttpGet("juriler")]
    public IActionResult Juries() => Page(
        "Jüriler",
        "Jüri üyelerini, gruplarını ve atamalarını yönetin.");

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

        return View(new PlayDetailsViewModel
        {
            Id = play.Id,
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            ContactPersonName = play.ContactPersonName,
            ContactPersonPhone = play.ContactPersonPhone,
            Phone = play.Phone,
            Email = play.Email,
            Address = play.Address,
            FromKunye = play.FromKunye
        });
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