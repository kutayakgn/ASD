using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("JuryLogs")]
public sealed class JuryLog
{
    [Key]
    public Guid Id { get; set; }
    public Guid CorrelationId { get; set; }
    public Guid? JuryId { get; set; }
    public string? JuryUsername { get; set; }
    public Guid? PlayId { get; set; }
    public string? PlayName { get; set; }
    public Guid? AdditionalVotingId { get; set; }
    public Guid? AdditionalVotingUsageId { get; set; }
    public byte? AdditionalVotingUsageType { get; set; }
    public bool IsAdditionalVoting { get; set; }
    public string OperationName { get; set; } = string.Empty;
    public string OperationType { get; set; } = string.Empty;
    public string? SubmittedVotesJson { get; set; }
    public string? OldVotesJson { get; set; }
    public string? NewVotesJson { get; set; }
    public decimal? SubmittedTicketFee { get; set; }
    public decimal? OldTicketFee { get; set; }
    public decimal? NewTicketFee { get; set; }
    public string? RequestPayloadJson { get; set; }
    public string? StateSnapshotJson { get; set; }
    public int AffectedVoteCount { get; set; }
    public DateTime OccurredAt { get; set; }
    public long? DurationMilliseconds { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string? HttpMethod { get; set; }
    public string? RequestPath { get; set; }
    public string? ControllerName { get; set; }
    public string? ActionName { get; set; }
    public string Application { get; set; } = "AfifeJury";
    public string Source { get; set; } = "JuryPanel";
    public bool IsSuccessful { get; set; }
    public string? ResultCode { get; set; }
    public string? Details { get; set; }
    public string? FailureReason { get; set; }
    public bool IsPublished { get; set; } = true;

    public User? Jury { get; set; }
    public Play? Play { get; set; }
    public AdditionalVoting? AdditionalVoting { get; set; }
}
