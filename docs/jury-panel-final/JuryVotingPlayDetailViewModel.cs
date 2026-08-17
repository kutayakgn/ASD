namespace YkbAfife.Domain.Model.Data.JuryVoting;

public sealed class JuryVotingPlayDetailViewModel
{
    public string ResultCode { get; set; } = JuryVotingResultCodes.Success;
    public Guid UserId { get; set; }
    public Guid PlayId { get; set; }
    public string PlayName { get; set; } = string.Empty;
    public string PlayDescription { get; set; } = string.Empty;
    public string CoverPhoto { get; set; } = string.Empty;
    public string TheaterName { get; set; } = string.Empty;
    public int PlayStatusCode { get; set; }
    public bool IsBlacklisted { get; set; }
    public bool IsSourceFormEligible { get; set; }
    public Guid? AdditionalVotingId { get; set; }
    public Guid? TicketFeeId { get; set; }
    public decimal? TicketFee { get; set; }
    public bool IsTicketFeeEditable { get; set; }
    public bool IsVotingActive { get; set; }
    public bool CanEditExistingVotes { get; set; }
    public bool CanSubmit { get; set; }
    public bool ShowAwardCategories { get; set; }
    public string AwardCategoriesMessage { get; set; } = string.Empty;
    public IReadOnlyList<JuryVotingPlayAwardCategoryScoreViewModel> AwardCategories { get; set; } = [];
}

public sealed class JuryVotingPlayAwardCategoryScoreViewModel
{
    public string CategoryName { get; set; } = string.Empty;
    public int AwardCategoryCode { get; set; }
    public string Role { get; set; } = string.Empty;
    public int RoleCode { get; set; }
    public string CategoryDisplayName => string.IsNullOrWhiteSpace(Role) ? CategoryName : $"{CategoryName} ({Role})";
    public Guid SelectedPlayAwardCategoryId { get; set; }
    public Guid? SelectedJuryVoteId { get; set; }
    public string SelectedCandidate { get; set; } = string.Empty;
    public string SelectedPlayCategoryPhoto { get; set; } = string.Empty;
    public int? SelectedScore { get; set; }
    public int OriginalScore => SelectedScore ?? 0;
    public bool IsEditable { get; set; }
    public IReadOnlyList<JuryVotingPlayAwardCategoryCandidateOptionViewModel> Candidates { get; set; } = [];
}

public sealed class JuryVotingPlayAwardCategoryCandidateOptionViewModel
{
    public Guid PlayAwardCategoryId { get; set; }
    public string Candidate { get; set; } = string.Empty;
    public string PlayCategoryPhoto { get; set; } = string.Empty;
    public Guid? JuryVoteId { get; set; }
    public int? Score { get; set; }
    public bool IsCurrent { get; set; }
}
