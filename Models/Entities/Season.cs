using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Seasons")]
public sealed class Season
{
    [Key]
    public Guid Id { get; set; }
    public DateOnly SeasonStartDate { get; set; }
    public DateOnly SeasonEndDate { get; set; }
    public DateOnly KunyeRegistrationStartDate { get; set; }
    public DateOnly KunyeRegistrationEndDate { get; set; }
    public DateOnly VotingStartDate { get; set; }
    public DateOnly VotingEndDate { get; set; }
    public int PlayCount { get; set; }
    public int ActivePlayCount { get; set; }
    public int VoteCount { get; set; }
    public bool IsPublished { get; set; }
}
