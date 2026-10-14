using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class CandidateReportService(AfifeContext context) : ICandidateReportService
{
    public async Task<CandidateTableViewModel> GetPageAsync(
        CandidateTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var rows = BuildQuery(normalized);
        var totalCount = await rows.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)CandidateTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var pageRows = await ApplyOrdering(rows, normalized.SortBy, normalized.SortDirection)
            .Skip((currentPage - 1) * CandidateTableViewModel.PageSize)
            .Take(CandidateTableViewModel.PageSize)
            .ToArrayAsync(cancellationToken);
        var categories = await context.AwardCategories
            .AsNoTracking()
            .Where(category => category.IsPublished)
            .OrderBy(category => category.CategoryCode)
            .Select(category => new CandidateCategoryFilterViewModel
            {
                CategoryCode = category.CategoryCode,
                CategoryName = category.CategoryName
            })
            .ToArrayAsync(cancellationToken);

        return new CandidateTableViewModel
        {
            PlayId = normalized.PlayId,
            CategoryCode = normalized.CategoryCode,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Categories = categories,
            Rows = pageRows
        };
    }

    public async Task<IReadOnlyList<CandidateTableRowViewModel>> GetExportRowsAsync(
        CandidateTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        return await ApplyOrdering(BuildQuery(normalized), normalized.SortBy, normalized.SortDirection)
            .ToArrayAsync(cancellationToken);
    }

    private IQueryable<CandidateTableRowViewModel> BuildQuery(CandidateTableQuery query)
    {
        var candidates =
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join category in context.AwardCategories.AsNoTracking()
                on candidate.AwardCategoryCode equals category.CategoryCode
            where candidate.PlayId == query.PlayId
               && candidate.IsPublished
               && category.IsPublished
               && (!query.CategoryCode.HasValue || candidate.AwardCategoryCode == query.CategoryCode.Value)
            select new CandidateTableRowViewModel
            {
                Id = candidate.Id,
                CategoryCode = candidate.AwardCategoryCode,
                CategoryName = category.CategoryName,
                Candidate = candidate.Candidate,
                Role = candidate.Role ?? string.Empty,
                IsCurrent = candidate.IsCurrent,
                RoleCandidateCount = context.PlayAwardCategories.Count(other =>
                    other.PlayId == candidate.PlayId &&
                    other.AwardCategoryCode == candidate.AwardCategoryCode &&
                    other.RoleCode == candidate.RoleCode &&
                    other.IsPublished),
                CreatedAt = candidate.CreatedAt,
                IsActive = candidate.IsActive
            };
        return candidates;
    }

    private static IOrderedQueryable<CandidateTableRowViewModel> ApplyOrdering(
        IQueryable<CandidateTableRowViewModel> rows,
        string sortBy,
        string sortDirection)
    {
        var descending = sortDirection == "desc";
        return sortBy switch
        {
            CandidateSortColumns.Candidate => descending
                ? rows.OrderByDescending(row => row.Candidate).ThenBy(row => row.Id)
                : rows.OrderBy(row => row.Candidate).ThenBy(row => row.Id),
            CandidateSortColumns.Role => descending
                ? rows.OrderByDescending(row => row.Role).ThenBy(row => row.Candidate)
                : rows.OrderBy(row => row.Role).ThenBy(row => row.Candidate),
            CandidateSortColumns.Replacement => descending
                ? rows.OrderByDescending(row => row.RoleCandidateCount).ThenByDescending(row => row.IsCurrent)
                : rows.OrderBy(row => row.RoleCandidateCount).ThenBy(row => row.IsCurrent),
            CandidateSortColumns.CreatedAt => descending
                ? rows.OrderByDescending(row => row.CreatedAt).ThenBy(row => row.Candidate)
                : rows.OrderBy(row => row.CreatedAt).ThenBy(row => row.Candidate),
            CandidateSortColumns.Status => descending
                ? rows.OrderByDescending(row => row.IsActive).ThenBy(row => row.Candidate)
                : rows.OrderBy(row => row.IsActive).ThenBy(row => row.Candidate),
            _ => descending
                ? rows.OrderByDescending(row => row.CategoryCode).ThenBy(row => row.Candidate).ThenBy(row => row.Id)
                : rows.OrderBy(row => row.CategoryCode).ThenBy(row => row.Candidate).ThenBy(row => row.Id)
        };
    }

    private static CandidateTableQuery Normalize(CandidateTableQuery query)
    {
        var allowed = new HashSet<string>(StringComparer.Ordinal)
        {
            CandidateSortColumns.Category,
            CandidateSortColumns.Candidate,
            CandidateSortColumns.Role,
            CandidateSortColumns.Replacement,
            CandidateSortColumns.CreatedAt,
            CandidateSortColumns.Status
        };
        return new CandidateTableQuery
        {
            PlayId = query.PlayId,
            CategoryCode = query.CategoryCode,
            SortBy = allowed.Contains(query.SortBy) ? query.SortBy : CandidateSortColumns.Category,
            SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc",
            Page = Math.Max(1, query.Page)
        };
    }
}
