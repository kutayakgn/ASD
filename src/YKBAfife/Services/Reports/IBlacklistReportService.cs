using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IBlacklistReportService
{
    Task<BlacklistTableViewModel> GetPageAsync(BlacklistTableQuery query, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<BlacklistRowViewModel>> GetExportRowsAsync(BlacklistTableQuery query, CancellationToken cancellationToken = default);
}
