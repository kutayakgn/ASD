namespace YKBAfife.Services.Audit;

public interface IAdminActionAuditLogger
{
    Task LogAsync(
        AdminAuditRequestContext request,
        string operationType,
        bool isSuccessful,
        int statusCode,
        string? details,
        string? failureReason,
        CancellationToken cancellationToken);
}
