using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class JuryReportService(AfifeContext context) : IJuryReportService
{
    public async Task<JuryTableViewModel> GetPageAsync(
        JuryTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var isCurrent = normalized.Tab == JuryTabs.Current;

        var users = context.Users
            .AsNoTracking()
            .Where(user => user.IsPublished && user.RoleCode == 2 && user.IsActive == isCurrent);

        if (!string.IsNullOrWhiteSpace(normalized.Search))
        {
            var search = normalized.Search;
            users = users.Where(user =>
                user.Username.Contains(search) ||
                user.Email.Contains(search) ||
                (user.FirstName + " " + user.LastName).Contains(search) ||
                (user.Phone != null && user.Phone.Contains(search)));
        }

        var totalCount = await users.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)JuryTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var watchedPlays = BuildWatchedPlaysQuery();

        var rowsQuery = users.Select(user => new JuryTableRowViewModel
        {
            UserId = user.Id,
            Username = user.Username,
            Email = user.Email,
            FullName = (user.FirstName + " " + user.LastName).Trim(),
            Phone = user.Phone ?? "-",
            WatchCount = isCurrent
                ? watchedPlays.Count(watch => watch.JuryId == user.Id)
                : 0,
            CreatedAt = user.CreatedAt
        });

        var rows = await ApplySorting(rowsQuery, normalized)
            .Skip((currentPage - 1) * JuryTableViewModel.PageSize)
            .Take(JuryTableViewModel.PageSize)
            .ToListAsync(cancellationToken);

        return new JuryTableViewModel
        {
            CurrentTab = normalized.Tab,
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private IQueryable<JuryPlayRow> BuildWatchedPlaysQuery()
    {
        var votedPlays =
            from vote in context.JuryVotes.AsNoTracking()
            join category in context.PlayAwardCategories.AsNoTracking()
                on vote.PlayAwardCategoryId equals category.Id
            where vote.IsPublished && vote.IsActive && category.IsPublished && category.IsActive
            select new JuryPlayRow
            {
                JuryId = vote.JuryId,
                PlayId = category.PlayId
            };

        var ticketedPlays =
            from ticket in context.JuryGameTicketFees.AsNoTracking()
            where ticket.IsPublished
            select new JuryPlayRow
            {
                JuryId = ticket.UserId,
                PlayId = ticket.PlayId
            };

        return votedPlays.Union(ticketedPlays);
    }

    private static IOrderedQueryable<JuryTableRowViewModel> ApplySorting(
        IQueryable<JuryTableRowViewModel> query,
        JuryTableQuery options)
    {
        var descending = options.SortDirection == "desc";

        return options.SortBy switch
        {
            JurySortColumns.Email => descending
                ? query.OrderByDescending(row => row.Email).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.Email).ThenBy(row => row.UserId),
            JurySortColumns.FullName => descending
                ? query.OrderByDescending(row => row.FullName).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.FullName).ThenBy(row => row.UserId),
            JurySortColumns.Phone => descending
                ? query.OrderByDescending(row => row.Phone).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.Phone).ThenBy(row => row.UserId),
            JurySortColumns.WatchCount => descending
                ? query.OrderByDescending(row => row.WatchCount).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.WatchCount).ThenBy(row => row.UserId),
            JurySortColumns.CreatedAt => descending
                ? query.OrderByDescending(row => row.CreatedAt).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.CreatedAt).ThenBy(row => row.UserId),
            _ => descending
                ? query.OrderByDescending(row => row.Username).ThenBy(row => row.UserId)
                : query.OrderBy(row => row.Username).ThenBy(row => row.UserId)
        };
    }

    private static JuryTableQuery Normalize(JuryTableQuery query)
    {
        var tab = query.Tab == JuryTabs.Historical ? JuryTabs.Historical : JuryTabs.Current;
        var allowedSortColumns = tab == JuryTabs.Historical
            ? new[] { JurySortColumns.Username, JurySortColumns.Email, JurySortColumns.FullName, JurySortColumns.Phone }
            : new[]
            {
                JurySortColumns.Username,
                JurySortColumns.Email,
                JurySortColumns.FullName,
                JurySortColumns.Phone,
                JurySortColumns.WatchCount,
                JurySortColumns.CreatedAt
            };

        return new JuryTableQuery
        {
            Tab = tab,
            Search = (query.Search ?? string.Empty).Trim(),
            SortBy = allowedSortColumns.Contains(query.SortBy) ? query.SortBy : JurySortColumns.Username,
            SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase)
                ? "desc"
                : "asc",
            Page = Math.Max(1, query.Page)
        };
    }

    private sealed class JuryPlayRow
    {
        public Guid JuryId { get; init; }
        public Guid PlayId { get; init; }
    }
}
