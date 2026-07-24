namespace YKBAfife.Models.ViewModels;

public sealed class CandidateDetailsViewModel
{
    public Guid Id { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string PlaySlug { get; init; } = string.Empty;
    public string CategoryName { get; init; } = string.Empty;
    public string Candidate { get; init; } = string.Empty;
    public string Role { get; init; } = string.Empty;
    public string CurrentState { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime? CreatedAt { get; init; }
}