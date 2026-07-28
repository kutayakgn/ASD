using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace YKBAfife.Models.Entities;

[Table("AdminLogs")]
public sealed class AdminLog
{
    [Key]
    public Guid Id { get; set; }
    public Guid CorrelationId { get; set; }
    public Guid? UserId { get; set; }
    public string? Username { get; set; }
    public string OperationName { get; set; } = string.Empty;
    public string OperationType { get; set; } = string.Empty;
    public string? SchemaName { get; set; }
    public string? TableName { get; set; }
    public string? EntityKey { get; set; }
    public string? OldValues { get; set; }
    public string? NewValues { get; set; }
    public int AffectedRowCount { get; set; }
    public DateTime OccurredAt { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string Application { get; set; } = "AfifeAdmin";
    public string? HttpMethod { get; set; }
    public string? RequestPath { get; set; }
    public string? ControllerName { get; set; }
    public string? ActionName { get; set; }
    public string Source { get; set; } = string.Empty;
    public bool IsSuccessful { get; set; }
    public string? Details { get; set; }
    public string? FailureReason { get; set; }
    public bool IsPublished { get; set; }
}
