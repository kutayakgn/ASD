namespace YKBAfife.Models.ViewModels;

public sealed class JuryWatchedPlayTableQuery
{
    public Guid JuryId { get; set; }
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = JuryWatchedPlaySortColumns.PlayName;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
}

public sealed class JuryWatchedPlayTableViewModel
{
    public const int PageSize = 10;

    public Guid JuryId { get; init; }
    public string JuryName { get; init; } = string.Empty;
    public string Search { get; init; } = string.Empty;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<JuryWatchedPlayRowViewModel> Rows { get; init; } = [];
}

public sealed class JuryWatchedPlayRowViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public DateTime? WatchedAt { get; init; }
}

public sealed class JuryWatchedPlayExportViewModel
{
    public Guid JuryId { get; init; }
    public string JuryName { get; init; } = string.Empty;
    public IReadOnlyList<JuryWatchedPlayRowViewModel> Rows { get; init; } = [];
}

public static class JuryWatchedPlaySortColumns
{
    public const string PlayName = "playName";
}
