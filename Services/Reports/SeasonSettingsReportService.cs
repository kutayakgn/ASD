using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class SeasonSettingsReportService(AfifeContext context) : ISeasonSettingsReportService
{
    public async Task<SeasonSettingsTableViewModel> GetPageAsync(
        SeasonSettingsTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var seasons = context.Seasons.AsNoTracking().Where(season => season.IsPublished);
        var totalCount = await seasons.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)SeasonSettingsTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);

        var rows = await ApplySorting(seasons, normalized)
            .Skip((currentPage - 1) * SeasonSettingsTableViewModel.PageSize)
            .Take(SeasonSettingsTableViewModel.PageSize)
            .Select(season => new SeasonSettingsRowViewModel
            {
                Id = season.Id,
                SeasonStartDate = season.SeasonStartDate,
                KunyeRegistrationStartDate = season.KunyeRegistrationStartDate,
                KunyeRegistrationEndDate = season.KunyeRegistrationEndDate,
                VotingStartDate = season.VotingStartDate,
                VotingEndDate = season.VotingEndDate,
                SeasonEndDate = season.SeasonEndDate
            })
            .ToArrayAsync(cancellationToken);

        return new SeasonSettingsTableViewModel
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
        SeasonSettingsTableQuery query)
    {
        var descending = query.SortDirection == "desc";
        return query.SortBy switch
        {
            SeasonSettingsSortColumns.SeasonStartDate => OrderBy(seasons, season => season.SeasonStartDate, descending),
            SeasonSettingsSortColumns.KunyeRegistrationStartDate => OrderBy(seasons, season => season.KunyeRegistrationStartDate, descending),
            SeasonSettingsSortColumns.KunyeRegistrationEndDate => OrderBy(seasons, season => season.KunyeRegistrationEndDate, descending),
            SeasonSettingsSortColumns.VotingStartDate => OrderBy(seasons, season => season.VotingStartDate, descending),
            SeasonSettingsSortColumns.VotingEndDate => OrderBy(seasons, season => season.VotingEndDate, descending),
            SeasonSettingsSortColumns.SeasonEndDate => OrderBy(seasons, season => season.SeasonEndDate, descending),
            _ => descending
                ? seasons.OrderByDescending(season => season.SeasonStartDate).ThenByDescending(season => season.SeasonEndDate)
                : seasons.OrderBy(season => season.SeasonStartDate).ThenBy(season => season.SeasonEndDate)
        };
    }

    private static IOrderedQueryable<Season> OrderBy(
        IQueryable<Season> seasons,
        System.Linq.Expressions.Expression<Func<Season, DateOnly>> selector,
        bool descending) => descending
            ? seasons.OrderByDescending(selector).ThenByDescending(season => season.SeasonStartDate)
            : seasons.OrderBy(selector).ThenBy(season => season.SeasonStartDate);

    private static SeasonSettingsTableQuery Normalize(SeasonSettingsTableQuery query)
    {
        string[] allowedSortColumns =
        [
            SeasonSettingsSortColumns.Season,
            SeasonSettingsSortColumns.SeasonStartDate,
            SeasonSettingsSortColumns.KunyeRegistrationStartDate,
            SeasonSettingsSortColumns.KunyeRegistrationEndDate,
            SeasonSettingsSortColumns.VotingStartDate,
            SeasonSettingsSortColumns.VotingEndDate,
            SeasonSettingsSortColumns.SeasonEndDate
        ];

        return new SeasonSettingsTableQuery
        {
            SortBy = allowedSortColumns.Contains(query.SortBy) ? query.SortBy : SeasonSettingsSortColumns.Season,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase) ? "asc" : "desc",
            Page = Math.Max(1, query.Page)
        };
    }
}
