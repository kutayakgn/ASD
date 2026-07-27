using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Configs")]
public class Config
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }
    public string ConfigName { get; set; } = null!;
    public string ConfigValue { get; set; } = null!;
    [Column("created_at")]
    public DateTime CreatedAt { get; set; }
    [Column("created_by")]
    public Guid? CreatedBy { get; set; }
    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }
    [Column("updated_by")]
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
}
