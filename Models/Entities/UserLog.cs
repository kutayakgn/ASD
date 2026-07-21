using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("UsersLog")]
public sealed class UserLog
{
    [Key]
    public Guid Id { get; set; }
    public Guid? UserId { get; set; }
    public Guid? ActorUserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
    public bool IsSuccessful { get; set; }
    public DateTime OccurredAt { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string Application { get; set; } = string.Empty;
    public string? Details { get; set; }
    public string? FailureReason { get; set; }
    public string? OldValue { get; set; }
    public string? NewValue { get; set; }
    public Guid CorrelationId { get; set; }
    public bool IsPublished { get; set; }
}
