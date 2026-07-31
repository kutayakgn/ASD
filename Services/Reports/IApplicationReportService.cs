using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IApplicationReportService
{
    Task<ApplicationTableViewModel> GetPageAsync(ApplicationTableQuery query, CancellationToken cancellationToken = default);
}
