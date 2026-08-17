using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YkbAfife.Domain.Model.Entity.JuryVoting;

[Table("JuryLogs")]
public sealed class JuryLog : BaseEntity
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public Guid Id { get; set; }
    public Guid CorrelationId { get; set; }
    public Guid? JuryId { get; set; }
    [MaxLength(100)] public string? JuryUsername { get; set; }
    public Guid? PlayId { get; set; }
    [MaxLength(250)] public string? PlayName { get; set; }
    public Guid? AdditionalVotingId { get; set; }
    public Guid? AdditionalVotingUsageId { get; set; }
    public byte? AdditionalVotingUsageType { get; set; }
    public bool IsAdditionalVoting { get; set; }
    [MaxLength(256)] public string OperationName { get; set; } = string.Empty;
    [MaxLength(50)] public string OperationType { get; set; } = string.Empty;
    public string? SubmittedVotesJson { get; set; }
    public string? OldVotesJson { get; set; }
    public string? NewVotesJson { get; set; }
    [Column(TypeName = "decimal(10,2)")] public decimal? SubmittedTicketFee { get; set; }
    [Column(TypeName = "decimal(10,2)")] public decimal? OldTicketFee { get; set; }
    [Column(TypeName = "decimal(10,2)")] public decimal? NewTicketFee { get; set; }
    public string? RequestPayloadJson { get; set; }
    public string? StateSnapshotJson { get; set; }
    public int AffectedVoteCount { get; set; }
    public DateTime OccurredAt { get; set; }
    public long? DurationMilliseconds { get; set; }
    [MaxLength(64)] public string? IpAddress { get; set; }
    [MaxLength(1000)] public string? UserAgent { get; set; }
    [MaxLength(16)] public string? HttpMethod { get; set; }
    [MaxLength(2048)] public string? RequestPath { get; set; }
    [MaxLength(128)] public string? ControllerName { get; set; }
    [MaxLength(128)] public string? ActionName { get; set; }
    [MaxLength(100)] public string Application { get; set; } = "AfifeJury";
    [MaxLength(50)] public string Source { get; set; } = "JuryPanel";
    public bool IsSuccessful { get; set; }
    [MaxLength(100)] public string? ResultCode { get; set; }
    public string? Details { get; set; }
    [MaxLength(2000)] public string? FailureReason { get; set; }
    public bool IsPublished { get; set; } = true;
}
