using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("PlayAwardCategories")]
public class PlayAwardCategory
{
    [Key]
    public Guid Id { get; set; }
    public Guid PlayId { get; set; }
    public Guid? PhotoImageId { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public string Candidate { get; set; } = null!;
    public int AwardCategoryCode { get; set; }
    public bool IsCurrent { get; set; }
    public string? Role { get; set; }
    public int RoleCode { get; set; }
    public bool IsOld { get; set; }

    public Image? PhotoImage { get; set; }
    public Play Play { get; set; } = null!;
    public AwardCategory AwardCategory { get; set; } = null!;
    public ICollection<JuryVote> JuryVotes { get; set; } = [];
}
