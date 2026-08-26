using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("JuryPasswordResetTokens", Schema = "dbo")]
public sealed class JuryPasswordResetToken
{
    [Key]
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public byte[] TokenHash { get; set; } = [];

    public DateTime CreatedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? UsedAtUtc { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; } = [];

    public User User { get; set; } = null!;
}
