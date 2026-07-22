using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Blacklist")]
public sealed class Blacklist
{
    [Key]
    public Guid Id { get; set; }
    public Guid JuryId { get; set; }
    public Guid PlayId { get; set; }
    public Guid CreatedBy { get; set; }
    public DateTime CreatedOn { get; set; }
    public bool IsPublished { get; set; }

    public User Jury { get; set; } = null!;
    public Play Play { get; set; } = null!;
    public User Creator { get; set; } = null!;
}
