using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class BlacklistReportService(AfifeContext context) : IBlacklistReportService
{
    public async Task<BlacklistTableViewModel> GetPageAsync(BlacklistTableQuery query, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var records = ApplyFiltering(CreateQuery(), normalized.Search);
        var totalCount = await records.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)BlacklistTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var rows = await ApplySorting(records, normalized)
            .Skip((currentPage - 1) * BlacklistTableViewModel.PageSize)
            .Take(BlacklistTableViewModel.PageSize)
            .ToArrayAsync(cancellationToken);

        return new BlacklistTableViewModel
        {
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    public async Task<IReadOnlyList<BlacklistRowViewModel>> GetExportRowsAsync(BlacklistTableQuery query, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        return await ApplySorting(ApplyFiltering(CreateQuery(), normalized.Search), normalized).ToArrayAsync(cancellationToken);
    }

    private IQueryable<BlacklistRowViewModel> CreateQuery() =>
        from blacklist in context.Blacklists.AsNoTracking()
        join jury in context.Users.AsNoTracking() on blacklist.JuryId equals jury.Id
        join play in context.Plays.AsNoTracking() on blacklist.PlayId equals play.Id
        join creator in context.Users.AsNoTracking() on blacklist.CreatedBy equals creator.Id
        where blacklist.IsPublished && jury.IsPublished && play.IsPublished && creator.IsPublished
        select new BlacklistRowViewModel
        {
            Id = blacklist.Id,
            JuryName = (jury.FirstName + " " + jury.LastName).Trim(),
            PlayName = play.PlayName,
            CreatedOn = blacklist.CreatedOn,
            CreatedByName = (creator.FirstName + " " + creator.LastName).Trim()
        };

    private static IQueryable<BlacklistRowViewModel> ApplyFiltering(IQueryable<BlacklistRowViewModel> records, string search)
    {
        if (string.IsNullOrWhiteSpace(search)) return records;
        var pattern = $"%{search}%";
        return records.Where(row =>
            EF.Functions.Like(row.JuryName, pattern) ||
            EF.Functions.Like(row.PlayName, pattern) ||
            EF.Functions.Like(row.CreatedByName, pattern));
    }

    private static IOrderedQueryable<BlacklistRowViewModel> ApplySorting(IQueryable<BlacklistRowViewModel> records, BlacklistTableQuery query)
    {
        var descending = query.SortDirection == "desc";
        return query.SortBy switch
        {
            BlacklistSortColumns.Jury => descending
                ? records.OrderByDescending(row => row.JuryName).ThenBy(row => row.PlayName)
                : records.OrderBy(row => row.JuryName).ThenBy(row => row.PlayName),
            BlacklistSortColumns.Play => descending
                ? records.OrderByDescending(row => row.PlayName).ThenBy(row => row.JuryName)
                : records.OrderBy(row => row.PlayName).ThenBy(row => row.JuryName),
            BlacklistSortColumns.CreatedBy => descending
                ? records.OrderByDescending(row => row.CreatedByName).ThenByDescending(row => row.CreatedOn)
                : records.OrderBy(row => row.CreatedByName).ThenByDescending(row => row.CreatedOn),
            _ => descending
                ? records.OrderByDescending(row => row.CreatedOn).ThenBy(row => row.JuryName)
                : records.OrderBy(row => row.CreatedOn).ThenBy(row => row.JuryName)
        };
    }

    private static BlacklistTableQuery Normalize(BlacklistTableQuery query)
    {
        string[] allowed =
        [
            BlacklistSortColumns.Jury,
            BlacklistSortColumns.Play,
            BlacklistSortColumns.CreatedOn,
            BlacklistSortColumns.CreatedBy
        ];
        return new BlacklistTableQuery
        {
            Search = (query.Search ?? string.Empty).Trim(),
            SortBy = allowed.Contains(query.SortBy) ? query.SortBy : BlacklistSortColumns.CreatedOn,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase) ? "asc" : "desc",
            Page = Math.Max(1, query.Page)
        };
    }
}
