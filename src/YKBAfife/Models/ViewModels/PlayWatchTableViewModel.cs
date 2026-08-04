namespace YKBAfife.Models.ViewModels;

public sealed class PlayWatchTableQuery
{
    public string Tab { get; set; } = PlayWatchTabs.FourOrMore;
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = PlayWatchSortColumns.ViewCount;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
}

public sealed class PlayWatchTableViewModel
{
    public const int PageSize = 10;

    public string CurrentTab { get; init; } = PlayWatchTabs.FourOrMore;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = PlayWatchSortColumns.ViewCount;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public int TotalViewCount { get; init; }
    public IReadOnlyList<PlayWatchRowViewModel> Rows { get; init; } = [];

    public int TotalPages => Math.Max(1, (int)Math.Ceiling(TotalCount / (double)PageSize));
}

public sealed class PlayWatchRowViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string? Slug { get; init; }
    public int ViewCount { get; init; }
}

public static class PlayWatchTabs
{
    public const string FourOrMore = "four-or-more";
    public const string UnderFour = "under-four";
}

public static class PlayWatchSortColumns
{
    public const string PlayName = "playName";
    public const string ViewCount = "viewCount";
}
