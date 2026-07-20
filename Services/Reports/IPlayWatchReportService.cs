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

    Task<PlayViewerTableViewModel> GetViewersPageAsync(
        PlayViewerTableQuery query,
        CancellationToken cancellationToken = default);

    Task<PlayViewerExportViewModel> GetViewersExportAsync(
        Guid playId,
        CancellationToken cancellationToken = default);
}