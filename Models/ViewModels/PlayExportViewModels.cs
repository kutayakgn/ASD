namespace YKBAfife.Models.ViewModels;

public sealed class PlayVoteExportRowViewModel
{
    public string JuryName { get; init; } = string.Empty;
    public string CategoryName { get; init; } = string.Empty;
    public string RoleName { get; init; } = string.Empty;
    public int Score { get; init; }
    public DateTime? VoteDate { get; init; }
    public bool IsActive { get; init; }
}