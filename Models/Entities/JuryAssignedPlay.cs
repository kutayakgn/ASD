using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("JuryAssignedPlays")]
public class JuryAssignedPlay
{
    [Key]
    public Guid Id { get; set; }
    public Guid PlayId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public Guid JuryId { get; set; }

    public Play Play { get; set; } = null!;
    public User Jury { get; set; } = null!;
}
