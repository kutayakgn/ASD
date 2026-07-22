using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IAdminReportService
{
    Task<AdminTableViewModel> GetPageAsync(AdminTableQuery query, CancellationToken cancellationToken = default);
}
