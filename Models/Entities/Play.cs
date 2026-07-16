using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Plays")]
public class Play
{
    [Key]
    public Guid Id { get; set; }
    public string PlayName { get; set; } = null!;
    public int StatusCode { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public string Slug { get; set; } = null!;
    public string TheaterName { get; set; } = null!;
    public string? Phone { get; set; }
    public string? ContactPersonName { get; set; }
    public string? ContactPersonPhone { get; set; }
    public string? Address { get; set; }
    public string? Email { get; set; }
    public bool FromKunye { get; set; }

    public PlayStatus Status { get; set; } = null!;
    public ICollection<JuryAssignedPlay> JuryAssignments { get; set; } = [];
    public ICollection<JuryGameTicketFee> JuryGameTicketFees { get; set; } = [];
    public ICollection<PlayAwardCategory> PlayAwardCategories { get; set; } = [];
}
