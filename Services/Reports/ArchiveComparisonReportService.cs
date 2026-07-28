using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class ArchiveComparisonReportService(AfifeContext context) : IArchiveComparisonReportService
{
    public async Task<ArchiveComparisonTableViewModel> GetPageAsync(
        ArchiveComparisonTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var seasons = context.Seasons
            .AsNoTracking()
            .Where(season => season.IsPublished);

        var totalCount = await seasons.CountAsync(cancellationToken);
        var totalPages = Math.Max(
            1,
            (int)Math.Ceiling(totalCount / (double)ArchiveComparisonTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var firstSeasonStartDate = await seasons
            .Select(season => (DateOnly?)season.SeasonStartDate)
            .MinAsync(cancellationToken);

        var pageRows = await ApplySorting(seasons, normalized)
            .Skip((currentPage - 1) * ArchiveComparisonTableViewModel.PageSize)
            .Take(ArchiveComparisonTableViewModel.PageSize)
            .Select(season => new
            {
                season.Id,
                season.SeasonStartDate,
                season.SeasonEndDate,
                season.PlayCount,
                season.ActivePlayCount,
                season.VoteCount
            })
            .ToArrayAsync(cancellationToken);

        var firstSeasonYear = firstSeasonStartDate?.Year;
        var rows = pageRows.Select(season => new ArchiveComparisonRowViewModel
        {
            Id = season.Id,
            SeasonNumber = firstSeasonYear.HasValue
                ? season.SeasonStartDate.Year - firstSeasonYear.Value + 1
                : 1,
            SeasonStartDate = season.SeasonStartDate,
            SeasonEndDate = season.SeasonEndDate,
            PlayCount = season.PlayCount,
            ActivePlayCount = season.ActivePlayCount,
            VoteCount = season.VoteCount
        }).ToArray();

        return new ArchiveComparisonTableViewModel
        {
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private static IOrderedQueryable<Season> ApplySorting(
        IQueryable<Season> seasons,
        ArchiveComparisonTableQuery query)
    {
        var descending = query.SortDirection == "desc";
        return query.SortBy switch
        {
            ArchiveComparisonSortColumns.PlayCount => descending
                ? seasons.OrderByDescending(season => season.PlayCount)
                    .ThenByDescending(season => season.SeasonStartDate)
                : seasons.OrderBy(season => season.PlayCount)
                    .ThenByDescending(season => season.SeasonStartDate),
            ArchiveComparisonSortColumns.ActivePlayCount => descending
                ? seasons.OrderByDescending(season => season.ActivePlayCount)
                    .ThenByDescending(season => season.SeasonStartDate)
                : seasons.OrderBy(season => season.ActivePlayCount)
                    .ThenByDescending(season => season.SeasonStartDate),
            ArchiveComparisonSortColumns.VoteCount => descending
                ? seasons.OrderByDescending(season => season.VoteCount)
                    .ThenByDescending(season => season.SeasonStartDate)
                : seasons.OrderBy(season => season.VoteCount)
                    .ThenByDescending(season => season.SeasonStartDate),
            _ => descending
                ? seasons.OrderByDescending(season => season.SeasonStartDate)
                : seasons.OrderBy(season => season.SeasonStartDate)
        };
    }

    private static ArchiveComparisonTableQuery Normalize(ArchiveComparisonTableQuery query)
    {
        string[] allowedSortColumns =
        [
            ArchiveComparisonSortColumns.Season,
            ArchiveComparisonSortColumns.PlayCount,
            ArchiveComparisonSortColumns.ActivePlayCount,
            ArchiveComparisonSortColumns.VoteCount
        ];

        return new ArchiveComparisonTableQuery
        {
            SortBy = allowedSortColumns.Contains(query.SortBy)
                ? query.SortBy
                : ArchiveComparisonSortColumns.Season,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase)
                ? "asc"
                : "desc",
            Page = Math.Max(1, query.Page)
        };
    }
}
