using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IPlayReportService
{
    Task<PlayTableViewModel> GetPageAsync(
        PlayTableQuery query,
        CancellationToken cancellationToken = default);
}
