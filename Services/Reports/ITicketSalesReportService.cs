using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface ITicketSalesReportService
{
    Task<TicketSalesTableViewModel> GetPageAsync(TicketSalesTableQuery query, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TicketSaleRowViewModel>> GetExportRowsAsync(TicketSalesTableQuery query, CancellationToken cancellationToken = default);
    Task<EditTicketFeeViewModel?> GetEditModelAsync(Guid id, CancellationToken cancellationToken = default);
}
