using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IArchiveComparisonReportService
{
    Task<ArchiveComparisonTableViewModel> GetPageAsync(
        ArchiveComparisonTableQuery query,
        CancellationToken cancellationToken = default);
}
