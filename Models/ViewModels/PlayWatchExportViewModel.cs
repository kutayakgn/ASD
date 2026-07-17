namespace YKBAfife.Models.ViewModels;

public sealed class PlayWatchExportViewModel
{
    public IReadOnlyList<PlayWatchExportJuryViewModel> Juries { get; init; } = [];
    public IReadOnlyList<PlayWatchExportRowViewModel> Rows { get; init; } = [];
}

public sealed class PlayWatchExportJuryViewModel
{
    public Guid Id { get; init; }
    public string FullName { get; init; } = string.Empty;
}

public sealed class PlayWatchExportRowViewModel
{
    public Guid PlayId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public int ViewCount { get; init; }
    public IReadOnlySet<Guid> ViewerIds { get; init; } = new HashSet<Guid>();
}
