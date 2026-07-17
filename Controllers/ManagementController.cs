using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Controllers;

public sealed class ManagementController : Controller
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
