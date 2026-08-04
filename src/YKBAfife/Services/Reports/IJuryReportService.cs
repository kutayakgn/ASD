using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IJuryReportService
{
    Task<JuryTableViewModel> GetPageAsync(
        JuryTableQuery query,
        CancellationToken cancellationToken = default);
}
