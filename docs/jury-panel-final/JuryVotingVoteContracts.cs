using System.Text.Json.Serialization;

namespace YkbAfife.Domain.Model.Data.JuryVoting;

public sealed class SaveVoteRequest
{
    public Guid PlayId { get; set; }

    // API yalnızca 1-99999 arası integer kabul eder. Veritabanı kolonu
    // geriye dönük uyumluluk için decimal(10,2) kalmaya devam eder.
    public int? TicketFee { get; set; }

    public Guid? TicketFeeId { get; set; }

    // Ekranda enabled olan her mantıksal kategori kartı gönderilmelidir.
    public List<CategoryVoteRequest> Scores { get; set; } = [];

    [JsonIgnore]
    public JuryOperationContext? OperationContext { get; set; }
}

public sealed class CategoryVoteRequest
{
    public Guid PlayAwardCategoryId { get; set; }
    public Guid? JuryVoteId { get; set; }
    public int Score { get; set; }
}

public sealed class JuryOperationContext
{
    public Guid CorrelationId { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string? HttpMethod { get; set; }
    public string? RequestPath { get; set; }
    public string? ControllerName { get; set; }
    public string? ActionName { get; set; }
}

public enum JuryVotingSaveVoteResult
{
    Success = 0,
    Unauthorized = 1,
    InvalidRequest = 2,
    JuryNotEligible = 3,
    PlayNotFound = 4,
    PlayNotEligible = 5,
    SourceFormNotEligible = 6,
    PlayStatusNotValidForVoting = 7,
    VotingClosed = 8,
    Blacklisted = 9,
    ScoreOutOfRange = 10,
    InvalidTicketFee = 11,
    CandidateNotEligible = 12,
    DuplicateCandidateSelection = 13,
    MultipleCandidatesForSameCard = 14,
    IncompleteVoteSet = 15,
    InconsistentExistingVotes = 16,
    AdditionalVotingNotAvailable = 17,
    AdditionalVotingAlreadyUsed = 18,
    NoChanges = 19,
    ConcurrencyConflict = 20,
    UnexpectedError = 21
}

public static class JuryVotingResultCodes
{
    public const string Success = "SUCCESS";
    public const string JuryNotEligible = "JURY_NOT_ELIGIBLE";
    public const string PlayNotFound = "PLAY_NOT_FOUND";
}
