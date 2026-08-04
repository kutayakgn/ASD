namespace YKBAfife.Models.ViewModels;

public sealed class PlayViewerTableQuery
{
    public Guid PlayId { get; set; }
    public int Page { get; set; } = 1;
}

public sealed class PlayViewerTableViewModel
{
    public const int PageSize = 10;

    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<PlayViewerRowViewModel> Rows { get; init; } = [];
}

public sealed class PlayViewerRowViewModel
{
    public Guid JuryId { get; init; }
    public string FullName { get; init; } = string.Empty;
}

public sealed class PlayViewerModalViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public Components.ComplexTableViewModel Table { get; init; } = new();
}

public sealed class PlayViewerExportViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public IReadOnlyList<PlayViewerRowViewModel> Viewers { get; init; } = [];
}