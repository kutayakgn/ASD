using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Roles")]
public class Role
{
    [Key]
    public Guid Id { get; set; }
    public string RoleName { get; set; } = null!;
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public int RoleCode { get; set; }

    public ICollection<User> Users { get; set; } = [];
}
