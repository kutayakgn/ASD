using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("JuryVotes")]
public class JuryVote
{
    [Key]
    public Guid Id { get; set; }
    public Guid PlayAwardCategoryId { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public bool IsActive { get; set; }
    public int Score { get; set; }
    public Guid JuryId { get; set; }

    public PlayAwardCategory PlayAwardCategory { get; set; } = null!;
    public User Jury { get; set; } = null!;
}
