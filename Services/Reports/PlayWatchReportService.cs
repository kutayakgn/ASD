using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class PlayWatchReportService(AfifeContext context) : IPlayWatchReportService
{
    public async Task<PlayWatchTableViewModel> GetPageAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var uniqueViewers = BuildUniqueViewerQuery();
        var filteredQuery = BuildFilteredQuery(normalized, uniqueViewers);

        var totalCount = await filteredQuery.CountAsync(cancellationToken);
        // Count the filtered unique viewer rows directly. SQL Server cannot SUM
        // a projection that already contains a correlated COUNT subquery.
        var filteredPlayIds = filteredQuery.Select(x => x.PlayId);
        var totalViewCount = await uniqueViewers
            .Where(viewer => filteredPlayIds.Contains(viewer.PlayId))
            .CountAsync(cancellationToken);

        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)PlayWatchTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);

        var rows = await ApplySorting(filteredQuery, normalized)
            .Skip((currentPage - 1) * PlayWatchTableViewModel.PageSize)
            .Take(PlayWatchTableViewModel.PageSize)
            .ToListAsync(cancellationToken);

        return new PlayWatchTableViewModel
        {
            CurrentTab = normalized.Tab,
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            TotalViewCount = totalViewCount,
            Rows = rows
        };
    }

    public async Task<IReadOnlyList<PlayWatchRowViewModel>> GetExportRowsAsync(
        PlayWatchTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var uniqueViewers = BuildUniqueViewerQuery();

        return await ApplySorting(BuildFilteredQuery(normalized, uniqueViewers), normalized)
            .ToListAsync(cancellationToken);
    }

    private IQueryable<PlayViewerRow> BuildUniqueViewerQuery()
    {
        var votedViewers =
            from vote in context.JuryVotes.AsNoTracking()
            join category in context.PlayAwardCategories.AsNoTracking()
                on vote.PlayAwardCategoryId equals category.Id
            where vote.IsPublished && category.IsPublished
            select new PlayViewerRow
            {
                PlayId = category.PlayId,
                UserId = vote.JuryId
            };

        var ticketViewers =
            from fee in context.JuryGameTicketFees.AsNoTracking()
            where fee.IsPublished
            select new PlayViewerRow
            {
                PlayId = fee.PlayId,
                UserId = fee.UserId
            };

        return votedViewers.Union(ticketViewers);
    }

    private IQueryable<PlayWatchRowViewModel> BuildFilteredQuery(
        PlayWatchTableQuery query,
        IQueryable<PlayViewerRow> uniqueViewers)
    {
        var reportQuery = context.Plays
            .AsNoTracking()
            .Where(x => x.IsPublished)
            .Select(play => new PlayWatchRowViewModel
            {
                PlayId = play.Id,
                PlayName = play.PlayName,
                ViewCount = uniqueViewers.Count(viewer => viewer.PlayId == play.Id)
            });

        reportQuery = query.Tab == PlayWatchTabs.UnderFour
            ? reportQuery.Where(x => x.ViewCount < 4)
            : reportQuery.Where(x => x.ViewCount >= 4);

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            reportQuery = reportQuery.Where(x => EF.Functions.Like(x.PlayName, $"%{query.Search}%"));
        }

        return reportQuery;
    }

    private static IOrderedQueryable<PlayWatchRowViewModel> ApplySorting(
        IQueryable<PlayWatchRowViewModel> query,
        PlayWatchTableQuery options)
    {
        var descending = options.SortDirection == "desc";

        return options.SortBy switch
        {
            PlayWatchSortColumns.PlayName when descending => query
                .OrderByDescending(x => x.PlayName)
                .ThenBy(x => x.PlayId),
            PlayWatchSortColumns.PlayName => query
                .OrderBy(x => x.PlayName)
                .ThenBy(x => x.PlayId),
            _ when descending => query
                .OrderByDescending(x => x.ViewCount)
                .ThenBy(x => x.PlayName)
                .ThenBy(x => x.PlayId),
            _ => query
                .OrderBy(x => x.ViewCount)
                .ThenBy(x => x.PlayName)
                .ThenBy(x => x.PlayId)
        };
    }

    private static PlayWatchTableQuery Normalize(PlayWatchTableQuery query)
    {
        var tab = query.Tab == PlayWatchTabs.UnderFour
            ? PlayWatchTabs.UnderFour
            : PlayWatchTabs.FourOrMore;

        var sortBy = query.SortBy == PlayWatchSortColumns.PlayName
            ? PlayWatchSortColumns.PlayName
            : PlayWatchSortColumns.ViewCount;

        return new PlayWatchTableQuery
        {
            Tab = tab,
            Search = query.Search?.Trim() ?? string.Empty,
            SortBy = sortBy,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase)
                ? "asc"
                : "desc",
            Page = Math.Max(1, query.Page)
        };
    }

    private sealed class PlayViewerRow
    {
        public Guid PlayId { get; init; }
        public Guid UserId { get; init; }
    }
}