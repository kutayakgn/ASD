using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("AdditionalVotingPlays")]
public sealed class AdditionalVotingPlay
{
    [Key] public Guid Id { get; set; }
    public Guid AdditionalVotingId { get; set; }
    public Guid PlayId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsActive { get; set; }
    public bool IsPublished { get; set; }
    public AdditionalVoting AdditionalVoting { get; set; } = null!;
    public Play Play { get; set; } = null!;
}
