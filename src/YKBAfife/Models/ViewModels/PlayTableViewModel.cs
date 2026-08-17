using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class PlaysDashboardViewModel
{
    public required ComplexTableViewModel PlaysTable { get; init; }
    public bool? JuryVotingStatus { get; init; }
    public bool? KunyeGirisStatus { get; init; }
    public bool? RecordType { get; init; }
}

public sealed class PlayTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = PlaySortColumns.PlayName;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
    public bool? JuryVotingStatus { get; set; }
    public bool? KunyeGirisStatus { get; set; }
    public bool? RecordType { get; set; }
}

public sealed class PlayTableViewModel
{
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = PlaySortColumns.PlayName;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public int JuryVotingEnabledCount { get; init; }
    public bool? JuryVotingStatus { get; init; }
    public bool? KunyeGirisStatus { get; init; }
    public bool? RecordType { get; init; }
    public IReadOnlyList<PlayTableRowViewModel> Rows { get; init; } = [];

    public const int PageSize = 10;
}

public sealed class PlayTableRowViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string TheaterName { get; init; } = string.Empty;
    public int StatusCode { get; init; }
    public bool RecordType { get; init; }
    public bool IsNew { get; init; }
    public bool HasSimilarPlay { get; init; }
    public IReadOnlyList<SimilarPlayViewModel> SimilarPlays { get; set; } = [];
    public DateTime? CreatedAt { get; init; }
    public bool JuriOylamaStatus { get; init; }
    public bool KunyeGirisStatus { get; init; }
    public string Slug { get; init; } = string.Empty;
}

public sealed class SimilarPlayViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string Slug { get; init; } = string.Empty;
}

public static class PlaySortColumns
{
    public const string PlayName = "playName";
    public const string TheaterName = "theaterName";
    public const string RecordType = "recordType";
    public const string CreatedAt = "createdAt";
    public const string JuryVotingStatus = "juryVotingStatus";
    public const string KunyeGirisStatus = "kunyeGirisStatus";
}
