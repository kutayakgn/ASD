using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Users")]
public class User
{
    [Key]
    public Guid Id { get; set; }
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string? Phone { get; set; }
    public Guid? PhotoImageId { get; set; }
    public string Username { get; set; } = null!;
    public string PasswordHash { get; set; } = null!;
    public string Email { get; set; } = null!;
    public DateTime? CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsPublished { get; set; }
    public int RoleCode { get; set; }
    public int? GroupCode { get; set; }

    public Image? PhotoImage { get; set; }
    public Role Role { get; set; } = null!;
    public Group? Group { get; set; }
    public ICollection<JuryAssignedPlay> AssignedPlays { get; set; } = [];
    public ICollection<JuryGameTicketFee> JuryGameTicketFees { get; set; } = [];
    public ICollection<JuryVote> JuryVotes { get; set; } = [];
}
