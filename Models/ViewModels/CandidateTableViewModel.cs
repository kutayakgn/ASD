using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class CandidateTableQuery
{
    public Guid PlayId { get; set; }
    public int? CategoryCode { get; set; }
    public string SortBy { get; set; } = CandidateSortColumns.Category;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
}

public sealed class CandidateTableViewModel
{
    public Guid PlayId { get; init; }
    public int? CategoryCode { get; init; }
    public string SortBy { get; init; } = CandidateSortColumns.Category;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<CandidateCategoryFilterViewModel> Categories { get; init; } = [];
    public IReadOnlyList<CandidateTableRowViewModel> Rows { get; init; } = [];
    public const int PageSize = 10;
}

public sealed class CandidateCategoryFilterViewModel
{
    public int CategoryCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
}

public sealed class CandidateTableRowViewModel
{
    public Guid Id { get; init; }
    public int CategoryCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public string Candidate { get; init; } = string.Empty;
    public string Role { get; init; } = string.Empty;
    public bool IsCurrent { get; init; }
    public int RoleCandidateCount { get; init; }
    public DateTime? CreatedAt { get; init; }
    public bool IsActive { get; init; }
}


public static class CandidateSortColumns
{
    public const string Category = "category";
    public const string Candidate = "candidate";
    public const string Role = "role";
    public const string Replacement = "replacement";
    public const string CreatedAt = "createdAt";
    public const string Status = "status";
}