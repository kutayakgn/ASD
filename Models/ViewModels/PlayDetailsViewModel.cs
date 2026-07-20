namespace YKBAfife.Models.ViewModels;

public sealed class PlayDetailsViewModel
{
    public Guid Id { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string TheaterName { get; init; } = string.Empty;
    public string? ContactPersonName { get; init; }
    public string? ContactPersonPhone { get; init; }
    public string? Phone { get; init; }
    public string? Email { get; init; }
    public string? Address { get; init; }
    public bool FromKunye { get; init; }
}
