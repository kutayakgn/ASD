using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IJuryWatchedPlayReportService
{
    Task<JuryWatchedPlayTableViewModel> GetPageAsync(
        JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken = default);

    Task<JuryWatchedPlayExportViewModel> GetExportAsync(
        JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken = default);
}
