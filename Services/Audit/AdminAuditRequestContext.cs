using System.Security.Claims;

namespace YKBAfife.Services.Audit;

public sealed record AdminAuditRequestContext(
    Guid CorrelationId,
    Guid? UserId,
    string? Username,
    string? IpAddress,
    string? UserAgent,
    string? HttpMethod,
    string? RequestPath,
    string? ControllerName,
    string? ActionName)
{
    private const string CorrelationItemKey = "AdminAudit.CorrelationId";

    public string OperationName =>
        string.IsNullOrWhiteSpace(ControllerName) || string.IsNullOrWhiteSpace(ActionName)
            ? $"{HttpMethod} {RequestPath}".Trim()
            : $"{ControllerName}.{ActionName}";

    public static AdminAuditRequestContext FromHttpContext(HttpContext? context)
    {
        if (context is null)
        {
            return new AdminAuditRequestContext(
                Guid.NewGuid(), null, null, null, null, null, null, null, null);
        }

        if (context.Items[CorrelationItemKey] is not Guid correlationId)
        {
            correlationId = Guid.TryParse(context.TraceIdentifier, out var traceIdentifier)
                ? traceIdentifier
                : Guid.NewGuid();
            context.Items[CorrelationItemKey] = correlationId;
        }

        var userId = Guid.TryParse(
            context.User.FindFirstValue(ClaimTypes.NameIdentifier),
            out var parsedUserId)
                ? parsedUserId
                : (Guid?)null;

        return new AdminAuditRequestContext(
            correlationId,
            userId,
            context.User.FindFirstValue("username"),
            context.Connection.RemoteIpAddress?.ToString(),
            context.Request.Headers.UserAgent.ToString(),
            context.Request.Method,
            context.Request.Path.Value,
            context.Request.RouteValues["controller"]?.ToString(),
            context.Request.RouteValues["action"]?.ToString());
    }
}
