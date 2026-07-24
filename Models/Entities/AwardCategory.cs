using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("AwardCategories")]
public class AwardCategory
{
    [Key]
    public Guid Id { get; set; }
    public string CategoryName { get; set; } = null!;
    public int CategoryCode { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public bool MultiCandidate { get; set; }

    public ICollection<PlayAwardCategory> PlayAwardCategories { get; set; } = [];
}
