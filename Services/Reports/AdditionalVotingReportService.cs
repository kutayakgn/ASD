using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class AdditionalVotingReportService(AfifeContext context) : IAdditionalVotingReportService
{
    public async Task<AdditionalVotingTableViewModel> GetPageAsync(AdditionalVotingTableQuery query, CancellationToken cancellationToken = default)
    {
        var sortBy = AllowedSortColumns.Contains(query.SortBy) ? query.SortBy : AdditionalVotingSortColumns.StartDate;
        var direction = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase) ? "asc" : "desc";
        var page = Math.Max(1, query.Page);
        var records = context.AdditionalVotings.AsNoTracking().Where(item => item.IsPublished);
        var totalCount = await records.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)AdditionalVotingTableViewModel.PageSize));
        page = Math.Min(page, totalPages);

        var projected = records.Select(item => new AdditionalVotingRowViewModel
        {
            Id = item.Id,
            StartDate = item.StartDate,
            EndDate = item.EndDate,
            AppliesToAllJuries = item.AppliesToAllJuries,
            AppliesToAllPlays = item.AppliesToAllPlays,
            JuryCount = item.EligibleJuries.Count(link => link.IsPublished && link.IsActive),
            PlayCount = item.EligiblePlays.Count(link => link.IsPublished && link.IsActive),
            FirstVoteUserCount = item.Usages.Where(usage => usage.IsPublished && usage.IsActive && usage.UsageType == AdditionalVotingUsageType.FirstVote).Select(usage => usage.JuryId).Distinct().Count(),
            VoteUpdateUserCount = item.Usages.Where(usage => usage.IsPublished && usage.IsActive && usage.UsageType == AdditionalVotingUsageType.VoteUpdate).Select(usage => usage.JuryId).Distinct().Count()
        });

        var ordered = ApplySorting(projected, sortBy, direction == "desc");
        var rows = await ordered.Skip((page - 1) * AdditionalVotingTableViewModel.PageSize)
            .Take(AdditionalVotingTableViewModel.PageSize).ToArrayAsync(cancellationToken);

        return new AdditionalVotingTableViewModel
        {
            SortBy = sortBy,
            SortDirection = direction,
            CurrentPage = page,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private static readonly string[] AllowedSortColumns =
    [
        AdditionalVotingSortColumns.StartDate, AdditionalVotingSortColumns.EndDate,
        AdditionalVotingSortColumns.Juries, AdditionalVotingSortColumns.Plays,
        AdditionalVotingSortColumns.FirstVotes, AdditionalVotingSortColumns.VoteUpdates
    ];

    private static IOrderedQueryable<AdditionalVotingRowViewModel> ApplySorting(
        IQueryable<AdditionalVotingRowViewModel> rows, string sortBy, bool descending) => sortBy switch
        {
            AdditionalVotingSortColumns.EndDate => descending ? rows.OrderByDescending(x => x.EndDate) : rows.OrderBy(x => x.EndDate),
            AdditionalVotingSortColumns.Juries => descending ? rows.OrderByDescending(x => x.AppliesToAllJuries).ThenByDescending(x => x.JuryCount) : rows.OrderBy(x => x.AppliesToAllJuries).ThenBy(x => x.JuryCount),
            AdditionalVotingSortColumns.Plays => descending ? rows.OrderByDescending(x => x.AppliesToAllPlays).ThenByDescending(x => x.PlayCount) : rows.OrderBy(x => x.AppliesToAllPlays).ThenBy(x => x.PlayCount),
            AdditionalVotingSortColumns.FirstVotes => descending ? rows.OrderByDescending(x => x.FirstVoteUserCount) : rows.OrderBy(x => x.FirstVoteUserCount),
            AdditionalVotingSortColumns.VoteUpdates => descending ? rows.OrderByDescending(x => x.VoteUpdateUserCount) : rows.OrderBy(x => x.VoteUpdateUserCount),
            _ => descending ? rows.OrderByDescending(x => x.StartDate).ThenByDescending(x => x.Id) : rows.OrderBy(x => x.StartDate).ThenBy(x => x.Id)
        };
}
