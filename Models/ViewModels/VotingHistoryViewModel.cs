namespace YKBAfife.Models.ViewModels;

public sealed class VotingHistoryViewModel
{
    public Guid? PlayId { get; init; }
    public Guid? JuryId { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public bool LockPlay { get; init; }
}

public sealed class VotingHistoryCardsViewModel
{
    public Guid PlayId { get; init; }
    public Guid JuryId { get; init; }
    public IReadOnlyList<VotingHistoryCategoryViewModel> Categories { get; init; } = [];
}

public sealed class VotingHistoryCategoryViewModel
{
    public int AwardCategoryCode { get; init; }
    public int RoleCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public string PlaceholderImageUrl { get; init; } = string.Empty;
    public Guid SelectedCandidateId { get; init; }
    public IReadOnlyList<VotingHistoryCandidateViewModel> Candidates { get; init; } = [];
}

public sealed class VotingHistoryCandidateViewModel
{
    public Guid Id { get; init; }
    public string DisplayName { get; init; } = string.Empty;
    public bool IsCurrent { get; init; }
    public bool HasVote { get; init; }
}
