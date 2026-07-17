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
    IPlayWatchExcelExporter excelExporter) : Controller
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
        var rows = await reportService.GetExportRowsAsync(query, cancellationToken);
        var title = query.Tab == PlayWatchTabs.UnderFour
            ? "4'ten Az İzlenen Oyunlar"
            : "4 Kez ve Üzeri İzlenen Oyunlar";
        var content = excelExporter.Export(rows, title);
        var fileName = $"oyun-izlenmeleri-{DateTime.Now:yyyyMMdd-HHmm}.xlsx";

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