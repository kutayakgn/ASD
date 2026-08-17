using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YkbAfife.Domain.Model.Entity.JuryVoting;

[Table("Blacklist")]
public sealed class Blacklist : BaseEntity
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public Guid Id { get; set; }
    public Guid JuryId { get; set; }
    public Guid PlayId { get; set; }
    public Guid CreatedBy { get; set; }
    public DateTime CreatedOn { get; set; }
    public bool IsPublished { get; set; }
}
