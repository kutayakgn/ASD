using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface ICandidateReportService
{
    Task<CandidateTableViewModel> GetPageAsync(CandidateTableQuery query, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CandidateTableRowViewModel>> GetExportRowsAsync(CandidateTableQuery query, CancellationToken cancellationToken = default);
}