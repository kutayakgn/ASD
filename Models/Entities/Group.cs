using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Group")]
public class Group
{
    [Key]
    public Guid Id { get; set; }
    public int Code { get; set; }
    public string GroupName { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }

    public ICollection<User> Users { get; set; } = [];
}
