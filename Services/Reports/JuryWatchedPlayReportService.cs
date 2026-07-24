using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class JuryWatchedPlayReportService(AfifeContext context) : IJuryWatchedPlayReportService
{
    public async Task<JuryWatchedPlayTableViewModel> GetPageAsync(
        JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var juryName = await GetJuryNameAsync(normalized.JuryId, cancellationToken);
        if (juryName is null)
        {
            return new JuryWatchedPlayTableViewModel { JuryId = normalized.JuryId };
        }

        var watchedPlays = BuildFilteredQuery(normalized);
        var totalCount = await watchedPlays.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)JuryWatchedPlayTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var rows = await ApplySorting(watchedPlays, normalized.SortDirection)
            .Skip((currentPage - 1) * JuryWatchedPlayTableViewModel.PageSize)
            .Take(JuryWatchedPlayTableViewModel.PageSize)
            .ToListAsync(cancellationToken);

        return new JuryWatchedPlayTableViewModel
        {
            JuryId = normalized.JuryId,
            JuryName = juryName,
            Search = normalized.Search,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    public async Task<JuryWatchedPlayExportViewModel> GetExportAsync(
        JuryWatchedPlayTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var juryName = await GetJuryNameAsync(normalized.JuryId, cancellationToken);
        if (juryName is null)
        {
            return new JuryWatchedPlayExportViewModel { JuryId = normalized.JuryId };
        }

        var rows = await ApplySorting(BuildFilteredQuery(normalized), normalized.SortDirection)
            .ToListAsync(cancellationToken);

        return new JuryWatchedPlayExportViewModel
        {
            JuryId = normalized.JuryId,
            JuryName = juryName,
            Rows = rows
        };
    }

    private async Task<string?> GetJuryNameAsync(Guid juryId, CancellationToken cancellationToken) =>
        await context.Users
            .AsNoTracking()
            .Where(user => user.Id == juryId && user.IsPublished && user.RoleCode == 2)
            .Select(user => (user.FirstName + " " + user.LastName).Trim())
            .SingleOrDefaultAsync(cancellationToken);

    private IQueryable<JuryWatchedPlayRowViewModel> BuildFilteredQuery(JuryWatchedPlayTableQuery query)
    {
        var votedPlays =
            from vote in context.JuryVotes.AsNoTracking()
            join category in context.PlayAwardCategories.AsNoTracking()
                on vote.PlayAwardCategoryId equals category.Id
            join play in context.Plays.AsNoTracking()
                on category.PlayId equals play.Id
            where vote.JuryId == query.JuryId
               && vote.IsPublished
               && vote.IsActive
               && category.IsPublished
               && category.IsActive
               && play.IsPublished
            select new WatchedPlayEvent
            {
                PlayId = play.Id,
                PlayName = play.PlayName,
                WatchedAt = vote.UpdatedAt ?? vote.CreatedAt
            };

        var ticketedPlays =
            from ticket in context.JuryGameTicketFees.AsNoTracking()
            join play in context.Plays.AsNoTracking()
                on ticket.PlayId equals play.Id
            where ticket.UserId == query.JuryId
               && ticket.IsPublished
               && play.IsPublished
            select new WatchedPlayEvent
            {
                PlayId = play.Id,
                PlayName = play.PlayName,
                WatchedAt = ticket.UpdatedAt ?? ticket.CreatedAt
            };

        var watchedPlays = votedPlays
            .Concat(ticketedPlays)
            .GroupBy(item => new { item.PlayId, item.PlayName })
            .Select(group => new JuryWatchedPlayRowViewModel
            {
                PlayId = group.Key.PlayId,
                PlayName = group.Key.PlayName,
                WatchedAt = group.Max(item => item.WatchedAt)
            });

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            watchedPlays = watchedPlays.Where(row => EF.Functions.Like(row.PlayName, $"%{query.Search}%"));
        }

        return watchedPlays;
    }

    private static IOrderedQueryable<JuryWatchedPlayRowViewModel> ApplySorting(
        IQueryable<JuryWatchedPlayRowViewModel> query,
        string sortDirection) =>
        sortDirection == "desc"
            ? query.OrderByDescending(row => row.PlayName).ThenBy(row => row.PlayId)
            : query.OrderBy(row => row.PlayName).ThenBy(row => row.PlayId);

    private static JuryWatchedPlayTableQuery Normalize(JuryWatchedPlayTableQuery query) => new()
    {
        JuryId = query.JuryId,
        Search = query.Search?.Trim() ?? string.Empty,
        SortBy = JuryWatchedPlaySortColumns.PlayName,
        SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase)
            ? "desc"
            : "asc",
        Page = Math.Max(1, query.Page)
    };

    private sealed class WatchedPlayEvent
    {
        public Guid PlayId { get; init; }
        public string PlayName { get; init; } = string.Empty;
        public DateTime? WatchedAt { get; init; }
    }
}
