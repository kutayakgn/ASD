using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("Rankings")]
public sealed class Ranking
{
    [Key]
    public Guid Id { get; private set; }
    public Guid PlayId { get; private set; }
    public Guid PlayAwardCategoryId { get; private set; }
    public int NumberOfActiveVote { get; private set; }
    public double? ArithmeticMean { get; private set; }
    public double? TrimmedMean { get; private set; }
    public int? ArithmeticRank { get; private set; }
    public int? TrimmedRank { get; private set; }
    public double? ArithmeticVariance { get; private set; }
    public int? ConfidenceValue { get; private set; }
    public bool IsPublished { get; private set; }

    public Play Play { get; private set; } = null!;
    public PlayAwardCategory PlayAwardCategory { get; private set; } = null!;
}
