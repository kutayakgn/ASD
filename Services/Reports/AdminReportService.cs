using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class AdminReportService(AfifeContext context) : IAdminReportService
{
    public async Task<AdminTableViewModel> GetPageAsync(
        AdminTableQuery query,
        Guid currentUserId,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var admins = context.Users
            .AsNoTracking()
            .Where(user => user.RoleCode == 1 && (user.IsPublished || user.Id == currentUserId));

        if (!string.IsNullOrWhiteSpace(normalized.Search))
        {
            var search = normalized.Search;
            admins = admins.Where(user =>
                user.Username.Contains(search) ||
                (user.FirstName + " " + user.LastName).Contains(search));
        }

        var totalCount = await admins.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)AdminTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);

        var rowsQuery = admins.Select(user => new AdminTableRowViewModel
        {
            UserId = user.Id,
            Username = user.Username,
            FullName = (user.FirstName + " " + user.LastName).Trim(),
            IsActive = user.IsActive
        });

        var ordered = normalized.SortBy == AdminSortColumns.FullName
            ? normalized.SortDirection == "desc"
                ? rowsQuery.OrderByDescending(row => row.FullName).ThenBy(row => row.UserId)
                : rowsQuery.OrderBy(row => row.FullName).ThenBy(row => row.UserId)
            : normalized.SortDirection == "desc"
                ? rowsQuery.OrderByDescending(row => row.Username).ThenBy(row => row.UserId)
                : rowsQuery.OrderBy(row => row.Username).ThenBy(row => row.UserId);

        var rows = await ordered
            .Skip((currentPage - 1) * AdminTableViewModel.PageSize)
            .Take(AdminTableViewModel.PageSize)
            .ToArrayAsync(cancellationToken);

        return new AdminTableViewModel
        {
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private static AdminTableQuery Normalize(AdminTableQuery query) => new()
    {
        Search = (query.Search ?? string.Empty).Trim(),
        SortBy = query.SortBy == AdminSortColumns.FullName ? AdminSortColumns.FullName : AdminSortColumns.Username,
        SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc",
        Page = Math.Max(1, query.Page)
    };
}
