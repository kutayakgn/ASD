using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("AdditionalVotingJuries")]
public sealed class AdditionalVotingJury
{
    [Key] public Guid Id { get; set; }
    public Guid AdditionalVotingId { get; set; }
    public Guid JuryId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsActive { get; set; }
    public bool IsPublished { get; set; }
    public AdditionalVoting AdditionalVoting { get; set; } = null!;
    public User Jury { get; set; } = null!;
}
