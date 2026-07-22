namespace YKBAfife.Models.ViewModels;

public sealed class ArchiveComparisonTableQuery
{
    public string SortBy { get; set; } = ArchiveComparisonSortColumns.Season;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
}

public sealed class ArchiveComparisonTableViewModel
{
    public const int PageSize = 10;

    public string SortBy { get; init; } = ArchiveComparisonSortColumns.Season;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<ArchiveComparisonRowViewModel> Rows { get; init; } = [];
}

public sealed class ArchiveComparisonRowViewModel
{
    public int SeasonNumber { get; init; }
    public int StartYear { get; init; }
    public string SeasonName => $"Sezon {SeasonNumber} ({StartYear}-{StartYear + 1})";
    public int PlayCount { get; init; }
    public int ActivePlayCount { get; init; }
    public int VoteCount { get; init; }
}

public sealed class ArchiveComparisonViewModel
{
    public Components.ComplexTableViewModel Table { get; init; } = new();
}

public static class ArchiveComparisonSortColumns
{
    public const string Season = "season";
    public const string PlayCount = "playCount";
    public const string ActivePlayCount = "activePlayCount";
    public const string VoteCount = "voteCount";
}
