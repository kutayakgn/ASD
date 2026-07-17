using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IPlayWatchReportService
{
    Task<PlayWatchTableViewModel> GetPageAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default);

    Task<PlayWatchExportViewModel> GetExportAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default);
}