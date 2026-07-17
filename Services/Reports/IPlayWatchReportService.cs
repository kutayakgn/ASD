using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IPlayWatchReportService
{
    Task<PlayWatchTableViewModel> GetPageAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PlayWatchRowViewModel>> GetExportRowsAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default);
}
