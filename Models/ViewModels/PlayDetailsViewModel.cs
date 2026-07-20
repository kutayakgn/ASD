namespace YKBAfife.Models.ViewModels;

public sealed class PlayDetailsViewModel
{
    public Guid Id { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string TheaterName { get; init; } = string.Empty;
    public bool JuriOylamaStatus { get; init; }
    public bool FromKunye { get; init; }
    public string JuryGroupInfo { get; init; } = string.Empty;
    public string PlayStatus { get; init; } = string.Empty;
    public string PlayStatusColor { get; init; } = "#6b7280";
    public bool RecordType { get; init; }
    public DateTime? CreatedAt { get; init; }
    public string? CreatedByName { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public string? UpdatedByName { get; init; }
    public string Slug { get; init; } = string.Empty;
}