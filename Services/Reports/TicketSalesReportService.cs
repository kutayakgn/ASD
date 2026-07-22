using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class TicketSalesReportService(AfifeContext context) : ITicketSalesReportService
{
    public async Task<TicketSalesTableViewModel> GetPageAsync(TicketSalesTableQuery query, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var records = ApplyFiltering(CreateQuery(), normalized.Search);
        var totalCount = await records.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)TicketSalesTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var rows = await ApplySorting(records, normalized)
            .Skip((currentPage - 1) * TicketSalesTableViewModel.PageSize)
            .Take(TicketSalesTableViewModel.PageSize)
            .ToArrayAsync(cancellationToken);

        return new TicketSalesTableViewModel
        {
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    public async Task<IReadOnlyList<TicketSaleRowViewModel>> GetExportRowsAsync(TicketSalesTableQuery query, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        return await ApplySorting(ApplyFiltering(CreateQuery(), normalized.Search), normalized).ToArrayAsync(cancellationToken);
    }

    public Task<EditTicketFeeViewModel?> GetEditModelAsync(Guid id, CancellationToken cancellationToken = default) =>
        CreateQuery().Where(row => row.Id == id).Select(row => new EditTicketFeeViewModel
        {
            Id = row.Id,
            JuryName = row.JuryName,
            PlayName = row.PlayName,
            TicketFee = row.TicketFee
        }).SingleOrDefaultAsync(cancellationToken);

    private IQueryable<TicketSaleRowViewModel> CreateQuery() =>
        from ticket in context.JuryGameTicketFees.AsNoTracking()
        join jury in context.Users.AsNoTracking() on ticket.UserId equals jury.Id
        join play in context.Plays.AsNoTracking() on ticket.PlayId equals play.Id
        where ticket.IsPublished && jury.IsPublished && play.IsPublished
        select new TicketSaleRowViewModel
        {
            Id = ticket.Id,
            JuryName = (jury.FirstName + " " + jury.LastName).Trim(),
            PlayName = play.PlayName,
            Date = ticket.CreatedAt,
            TicketFee = ticket.TicketFee
        };

    private static IQueryable<TicketSaleRowViewModel> ApplyFiltering(IQueryable<TicketSaleRowViewModel> records, string search)
    {
        if (string.IsNullOrWhiteSpace(search)) return records;
        var pattern = $"%{search}%";
        return records.Where(row => EF.Functions.Like(row.JuryName, pattern) || EF.Functions.Like(row.PlayName, pattern));
    }

    private static IOrderedQueryable<TicketSaleRowViewModel> ApplySorting(IQueryable<TicketSaleRowViewModel> records, TicketSalesTableQuery query)
    {
        var descending = query.SortDirection == "desc";
        return query.SortBy switch
        {
            TicketSalesSortColumns.Jury => descending ? records.OrderByDescending(row => row.JuryName).ThenBy(row => row.PlayName) : records.OrderBy(row => row.JuryName).ThenBy(row => row.PlayName),
            TicketSalesSortColumns.Play => descending ? records.OrderByDescending(row => row.PlayName).ThenBy(row => row.JuryName) : records.OrderBy(row => row.PlayName).ThenBy(row => row.JuryName),
            TicketSalesSortColumns.TicketFee => descending ? records.OrderByDescending(row => row.TicketFee).ThenByDescending(row => row.Date) : records.OrderBy(row => row.TicketFee).ThenByDescending(row => row.Date),
            _ => descending ? records.OrderByDescending(row => row.Date).ThenBy(row => row.JuryName) : records.OrderBy(row => row.Date).ThenBy(row => row.JuryName)
        };
    }

    private static TicketSalesTableQuery Normalize(TicketSalesTableQuery query)
    {
        string[] allowed = [TicketSalesSortColumns.Jury, TicketSalesSortColumns.Play, TicketSalesSortColumns.Date, TicketSalesSortColumns.TicketFee];
        return new TicketSalesTableQuery
        {
            Search = (query.Search ?? string.Empty).Trim(),
            SortBy = allowed.Contains(query.SortBy) ? query.SortBy : TicketSalesSortColumns.Date,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase) ? "asc" : "desc",
            Page = Math.Max(1, query.Page)
        };
    }
}
