namespace YKBAfife.Models.ViewModels;

public sealed class JuryTableQuery
{
    public string Tab { get; set; } = JuryTabs.Current;
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = JurySortColumns.Username;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
}

public sealed class JuryTableViewModel
{
    public const int PageSize = 10;

    public string CurrentTab { get; init; } = JuryTabs.Current;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = JurySortColumns.Username;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<JuryTableRowViewModel> Rows { get; init; } = [];
}

public sealed class JuryTableRowViewModel
{
    public Guid UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public int WatchCount { get; init; }
    public DateTime? CreatedAt { get; init; }
}

public sealed class JuryDashboardViewModel
{
    public Components.ComplexTableViewModel JuryTable { get; init; } = new();
}

public static class JuryTabs
{
    public const string Current = "current";
    public const string Historical = "historical";
}

public static class JurySortColumns
{
    public const string Username = "username";
    public const string Email = "email";
    public const string FullName = "fullName";
    public const string Phone = "phone";
    public const string WatchCount = "watchCount";
    public const string CreatedAt = "createdAt";
}
