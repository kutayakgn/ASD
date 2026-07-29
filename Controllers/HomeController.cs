using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Exports;
using YKBAfife.Services.Reports;

namespace YKBAfife.Controllers;

public sealed class HomeController(
    IPlayWatchReportService reportService,
    IExcelExporter excelExporter) : Controller
{
    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var report = await reportService.GetPageAsync(new PlayWatchTableQuery(), cancellationToken);
        return View(new HomeDashboardViewModel
        {
            PlayWatchTable = PlayWatchComplexTableFactory.Create(report)
        });
    }

    [HttpPost("oyun-izlenmeleri/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> PlayWatchTable(
        [FromForm] PlayWatchTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await reportService.GetPageAsync(query, cancellationToken);
        var model = PlayWatchComplexTableFactory.Create(report);

        return ViewComponent("ComplexTable", new { model });
    }

    [HttpPost("oyun-izlenmeleri/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Export(
        [FromForm] PlayWatchTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await reportService.GetExportAsync(query, cancellationToken);
        var title = query.Tab == PlayWatchTabs.UnderFour
            ? "4'ten Az İzlenen Oyunlar"
            : "4 Kez ve Üzeri İzlenen Oyunlar";
        var document = PlayWatchExcelExportFactory.Create(report, title, query);
        var content = excelExporter.Export(document);
        var fileName = $"oyun-izlenmeleri-{DateTime.Now:yyyyMMdd-HHmm}.xlsx";

        return File(
            content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            fileName);
    }

    [HttpGet("oyun-izlenmeleri/{playId:guid}/juriler")]
    public async Task<IActionResult> PlayViewersModal(
        Guid playId,
        CancellationToken cancellationToken)
    {
        var report = await reportService.GetViewersPageAsync(
            new PlayViewerTableQuery { PlayId = playId },
            cancellationToken);

        if (string.IsNullOrWhiteSpace(report.PlayName))
        {
            return NotFound();
        }

        return PartialView("_PlayViewersModal", new PlayViewerModalViewModel
        {
            PlayId = report.PlayId,
            PlayName = report.PlayName,
            Table = PlayViewerComplexTableFactory.Create(report)
        });
    }

    [HttpPost("oyun-izlenmeleri/juriler/tablo")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> PlayViewersTable(
        [FromForm] PlayViewerTableQuery query,
        CancellationToken cancellationToken)
    {
        var report = await reportService.GetViewersPageAsync(query, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.PlayName))
        {
            return NotFound();
        }

        return ViewComponent("ComplexTable", new
        {
            model = PlayViewerComplexTableFactory.Create(report)
        });
    }

    [HttpPost("oyun-izlenmeleri/juriler/excel")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ExportPlayViewers(
        [FromForm] Guid playId,
        CancellationToken cancellationToken)
    {
        var report = await reportService.GetViewersExportAsync(playId, cancellationToken);
        if (string.IsNullOrWhiteSpace(report.PlayName))
        {
            return NotFound();
        }

        var document = PlayViewerExcelExportFactory.Create(report.PlayName, report.Viewers);
        var content = excelExporter.Export(document);
        var fileName = $"oyunu-izleyen-juriler-{DateTime.Now:yyyyMMdd-HHmm}.xlsx";

        return File(
            content,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            fileName);
    }

    [AllowAnonymous]
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() => View(new ErrorViewModel
    {
        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
    });
}