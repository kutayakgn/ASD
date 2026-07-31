using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class ApplicationReportService(AfifeContext context) : IApplicationReportService
{
    private static readonly int[] AllowedPageSizes = [5, 10, 15, 20];

    public async Task<ApplicationTableViewModel> GetPageAsync(ApplicationTableQuery query, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var records = ApplyFiltering(CreateQuery(), normalized.Search);
        var totalCount = await records.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)normalized.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var rows = await ApplySorting(records, normalized)
            .Skip((currentPage - 1) * normalized.PageSize)
            .Take(normalized.PageSize)
            .ToArrayAsync(cancellationToken);

        return new ApplicationTableViewModel
        {
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            PageSize = normalized.PageSize,
            TotalCount = totalCount,
            Rows = rows
        };
    }

    private IQueryable<ApplicationRowViewModel> CreateQuery() =>
        context.Forms.AsNoTracking()
            .Where(form => form.IsPublished)
            .Select(form => new ApplicationRowViewModel
            {
                Id = form.Id,
                ApplicationNumber = form.ApplicationNumber,
                PlayName = form.RepertoireName,
                Email = form.Email,
                Phone = form.Phone,
                CreatedDate = form.CreatedDate,
                IsActive = form.IsActive
            });

    private static IQueryable<ApplicationRowViewModel> ApplyFiltering(IQueryable<ApplicationRowViewModel> records, string search)
    {
        if (string.IsNullOrWhiteSpace(search)) return records;
        var pattern = $"%{search}%";
        return records.Where(row =>
            EF.Functions.Like(row.ApplicationNumber, pattern) ||
            EF.Functions.Like(row.PlayName, pattern) ||
            EF.Functions.Like(row.Email, pattern) ||
            EF.Functions.Like(row.Phone, pattern));
    }

    private static IOrderedQueryable<ApplicationRowViewModel> ApplySorting(IQueryable<ApplicationRowViewModel> records, ApplicationTableQuery query)
    {
        var desc = query.SortDirection == "desc";
        return query.SortBy switch
        {
            ApplicationSortColumns.ApplicationNumber => desc ? records.OrderByDescending(x => x.ApplicationNumber) : records.OrderBy(x => x.ApplicationNumber),
            ApplicationSortColumns.Play => desc ? records.OrderByDescending(x => x.PlayName) : records.OrderBy(x => x.PlayName),
            ApplicationSortColumns.Email => desc ? records.OrderByDescending(x => x.Email) : records.OrderBy(x => x.Email),
            ApplicationSortColumns.Phone => desc ? records.OrderByDescending(x => x.Phone) : records.OrderBy(x => x.Phone),
            ApplicationSortColumns.Status => desc ? records.OrderByDescending(x => x.IsActive).ThenByDescending(x => x.CreatedDate) : records.OrderBy(x => x.IsActive).ThenByDescending(x => x.CreatedDate),
            _ => desc ? records.OrderByDescending(x => x.CreatedDate).ThenBy(x => x.ApplicationNumber) : records.OrderBy(x => x.CreatedDate).ThenBy(x => x.ApplicationNumber)
        };
    }

    private static ApplicationTableQuery Normalize(ApplicationTableQuery query)
    {
        string[] columns = [ApplicationSortColumns.ApplicationNumber, ApplicationSortColumns.Play, ApplicationSortColumns.Email, ApplicationSortColumns.Phone, ApplicationSortColumns.CreatedDate, ApplicationSortColumns.Status];
        return new ApplicationTableQuery
        {
            Search = (query.Search ?? string.Empty).Trim(),
            SortBy = columns.Contains(query.SortBy) ? query.SortBy : ApplicationSortColumns.CreatedDate,
            SortDirection = string.Equals(query.SortDirection, "asc", StringComparison.OrdinalIgnoreCase) ? "asc" : "desc",
            Page = Math.Max(1, query.Page),
            PageSize = AllowedPageSizes.Contains(query.PageSize) ? query.PageSize : 10
        };
    }
}
