namespace YKBAfife.Models.ViewModels;

public sealed class AdminLogFilterViewModel
{
    public Guid? CorrelationId { get; set; }
    public string? Username { get; set; }
    public string? OperationType { get; set; }
    public string? SchemaName { get; set; }
    public string? TableName { get; set; }
    public DateTime? OccurredFrom { get; set; }
    public DateTime? OccurredTo { get; set; }
    public string? ActionName { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 25;
}

public sealed class UserLogFilterViewModel
{
    public Guid? UserId { get; set; }
    public Guid? ActorUserId { get; set; }
    public string? Username { get; set; }
    public DateTime? OccurredFrom { get; set; }
    public DateTime? OccurredTo { get; set; }
    public string? Application { get; set; }
    public Guid? CorrelationId { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 25;
}

public sealed class AuditLogPageViewModel
{
    public string Title { get; init; } = string.Empty;
    public string LogType { get; init; } = string.Empty;
    public string BasePath { get; init; } = string.Empty;
    public AdminLogFilterViewModel? AdminFilter { get; init; }
    public UserLogFilterViewModel? UserFilter { get; init; }
    public IReadOnlyList<AuditLogRecordViewModel> Records { get; init; } = [];
    public int CurrentPage { get; init; }
    public int PageSize { get; init; }
    public int TotalCount { get; init; }
    public string? PreviousPageUrl { get; init; }
    public string? NextPageUrl { get; init; }
    public int TotalPages => Math.Max(1, (int)Math.Ceiling(TotalCount / (double)Math.Max(1, PageSize)));
}

public sealed class AuditLogRecordViewModel
{
    public Guid Id { get; init; }
    public DateTime OccurredAt { get; init; }
    public IReadOnlyList<AuditLogFieldViewModel> Fields { get; init; } = [];
}

public sealed class AuditLogFieldViewModel
{
    public string Name { get; init; } = string.Empty;
    public string? Value { get; init; }
    public bool IsLongValue { get; init; }
}