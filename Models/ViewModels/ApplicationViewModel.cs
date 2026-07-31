using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class ApplicationTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = ApplicationSortColumns.CreatedDate;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}

public sealed class ApplicationTableViewModel
{
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = ApplicationSortColumns.CreatedDate;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int PageSize { get; init; } = 10;
    public int TotalCount { get; init; }
    public IReadOnlyList<ApplicationRowViewModel> Rows { get; init; } = [];
}

public sealed class ApplicationRowViewModel
{
    public Guid Id { get; init; }
    public string ApplicationNumber { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public DateTime? CreatedDate { get; init; }
    public bool IsActive { get; init; }
}

public sealed class ApplicationsViewModel
{
    public ComplexTableViewModel Table { get; init; } = new();
}

public sealed class ApplicationDetailsViewModel
{
    public Guid Id { get; init; }
    public string ApplicationNumber { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public string TheatreName { get; init; } = string.Empty;
    public string ApplicantName { get; init; } = string.Empty;
    public string ApplicantRole { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public string Director { get; init; } = string.Empty;
    public DateOnly PremiereDate { get; init; }
    public DateTime? CreatedDate { get; init; }
    public bool IsActive { get; init; }
}

public static class ApplicationSortColumns
{
    public const string ApplicationNumber = "applicationNumber";
    public const string Play = "play";
    public const string Email = "email";
    public const string Phone = "phone";
    public const string CreatedDate = "createdDate";
    public const string Status = "status";
}
