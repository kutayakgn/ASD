using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("AdditionalVotings")]
public sealed class AdditionalVoting
{
    [Key] public Guid Id { get; set; }
    // Jury eligibility treats these DateOnly values as an inclusive interval:
    // StartDate 00:00:01 through EndDate 23:59:59 (Turkey local time).
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public bool AppliesToAllJuries { get; set; }
    public bool AppliesToAllPlays { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public bool IsActive { get; set; }
    public bool IsPublished { get; set; }
    public ICollection<AdditionalVotingJury> EligibleJuries { get; set; } = [];
    public ICollection<AdditionalVotingPlay> EligiblePlays { get; set; } = [];
    public ICollection<AdditionalVotingUsage> Usages { get; set; } = [];
}
