using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class ArchiveComparisonReportService(AfifeContext context) : IArchiveComparisonReportService
{
    private const int FirstSeasonStartYear = 2014;

    public async Task<ArchiveComparisonTableViewModel> GetPageAsync(
        ArchiveComparisonTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var latestSeasonStartYear = DateTime.Today.Month >= 9
            ? DateTime.Today.Year
            : DateTime.Today.Year - 1;
        var totalCount = Math.Max(0, latestSeasonStartYear - FirstSeasonStartYear + 1);

        var rangeStart = new DateTime(FirstSeasonStartYear, 9, 1);
        var rangeEnd = new DateTime(latestSeasonStartYear + 1, 5, 1);
        var playAggregates = await context.Plays
            .AsNoTracking()
            .Where(play => play.IsPublished
                && play.CreatedAt.HasValue
                && play.CreatedAt.Value >= rangeStart
                && play.CreatedAt.Value < rangeEnd
                && (play.CreatedAt.Value.Month >= 9 || play.CreatedAt.Value.Month < 5))
            .GroupBy(play => play.CreatedAt!.Value.Month >= 9
                ? play.CreatedAt.Value.Year
                : play.CreatedAt.Value.Year - 1)
            .Select(group => new
            {
                StartYear = group.Key,
                PlayCount = group.Count(),
                ActivePlayCount = group.Count(play => play.StatusCode == 1)
            })
            .ToDictionaryAsync(row => row.StartYear, cancellationToken);

        var voteAggregates = await (
            from vote in context.JuryVotes.AsNoTracking()
            join category in context.PlayAwardCategories.AsNoTracking()
                on vote.PlayAwardCategoryId equals category.Id
            join play in context.Plays.AsNoTracking()
                on category.PlayId equals play.Id
            where vote.IsPublished
                && category.IsPublished
                && play.IsPublished
                && play.CreatedAt.HasValue
                && play.CreatedAt.Value >= rangeStart
                && play.CreatedAt.Value < rangeEnd
                && (play.CreatedAt.Value.Month >= 9 || play.CreatedAt.Value.Month < 5)
            group vote by play.CreatedAt!.Value.Month >= 9
                ? play.CreatedAt.Value.Year
                : play.CreatedAt.Value.Year - 1
            into seasonVotes
            select new
            {
                StartYear = seasonVotes.Key,
                VoteCount = seasonVotes.Count()
            })
            .ToDictionaryAsync(row => row.StartYear, row => row.VoteCount, cancellationToken);

        var seasons = Enumerable.Range(FirstSeasonStartYear, totalCount)
            .Select((startYear, index) => new ArchiveComparisonRowViewModel
            {
                SeasonNumber = index + 1,
                StartYear = startYear,
                PlayCount = playAggregates.TryGetValue(startYear, out var playAggregate)
                    ? playAggregate.PlayCount
                    : 0,
                ActivePlayCount = playAggregates.TryGetValue(startYear, out playAggregate)
                    ? playAggregate.ActivePlayCount
                    : 0,
                VoteCount = voteAggregates.GetValueOrDefault(startYear)
            });

        var sortedSeasons = ApplySorting(seasons, normalized);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)ArchiveComparisonTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var rows = sortedSeasons
            .Skip((currentPage - 1) * ArchiveComparisonTableViewModel.PageSize)
            .Take(ArchiveComparisonTableViewModel.PageSize)
            .ToArray();

        return new ArchiveComparisonTableViewModel
        {
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private static IOrderedEnumerable<ArchiveComparisonRowViewModel> ApplySorting(
        IEnumerable<ArchiveComparisonRowViewModel> rows,
        ArchiveComparisonTableQuery query)
    {
        var descending = query.SortDirection == "desc";
        return query.SortBy switch
        {
            ArchiveComparisonSortColumns.PlayCount => descending
                ? rows.OrderByDescending(row => row.PlayCount).ThenBy(row => row.SeasonNumber)
                : rows.OrderBy(row => row.PlayCount).ThenBy(row => row.SeasonNumber),
            ArchiveComparisonSortColumns.ActivePlayCount => descending
                ? rows.OrderByDescending(row => row.ActivePlayCount).ThenBy(row => row.SeasonNumber)
                : rows.OrderBy(row => row.ActivePlayCount).ThenBy(row => row.SeasonNumber),
            ArchiveComparisonSortColumns.VoteCount => descending
                ? rows.OrderByDescending(row => row.VoteCount).ThenBy(row => row.SeasonNumber)
                : rows.OrderBy(row => row.VoteCount).ThenBy(row => row.SeasonNumber),
            _ => descending
                ? rows.OrderByDescending(row => row.SeasonNumber)
                : rows.OrderBy(row => row.SeasonNumber)
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
            SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase)
                ? "desc"
                : "asc",
            Page = Math.Max(1, query.Page)
        };
    }
}
