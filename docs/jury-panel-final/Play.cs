using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YkbAfife.Domain.Model.Entity.JuryVoting;

[Table("Plays")]
public class Play : BaseEntity
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public Guid Id { get; set; }

    [MaxLength(255)]
    public required string PlayName { get; set; }

    [MaxLength(255)]
    [Column(TypeName = "varchar(255)")]
    public required string Slug { get; set; }

    [MaxLength(255)]
    [Column(TypeName = "varchar(255)")]
    public required string TheaterName { get; set; }

    public string? Phone { get; set; }
    public string? ContactPersonName { get; set; }
    public string? ContactPersonPhone { get; set; }
    public string? Address { get; set; }
    public string? Email { get; set; }
    public int StatusCode { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public bool JuriOylamaStatus { get; set; }
    public bool KunyeGirisStatus { get; set; }

    // SQL Server kolonu bit'tir. Form kaynaklı oyun = false (0),
    // admin kaydı = true (1).
    public bool RecordType { get; set; }

    public Guid? SourceFormId { get; set; }
    public bool IsActive { get; set; }
}
