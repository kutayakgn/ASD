namespace YKBAfife.Models.ViewModels;

public sealed class JuryDetailsViewModel
{
    public Guid Id { get; init; }
    public Components.ComplexTableViewModel WatchedPlaysTable { get; init; } = new();
    public string Username { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public bool HasPhoto { get; init; }
    public bool IsActive { get; init; }
    public DateTime? LastLoginAt { get; init; }
    public DateTime? LastPasswordChangeAt { get; init; }
    public int SuccessfulLoginCount { get; init; }
    public int FailedLoginCount { get; init; }
    public DateTime? CreatedAt { get; init; }
    public string? CreatedByName { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public string? UpdatedByName { get; init; }
}
