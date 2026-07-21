using YKBAfife.Data;
using YKBAfife.Models.Entities;

namespace YKBAfife.Services.Audit;

public sealed class UserActivityLogger(
    AfifeContext context,
    IHttpContextAccessor httpContextAccessor) : IUserActivityLogger
{
    public async Task LogAsync(
        string eventType,
        bool isSuccessful,
        Guid? userId = null,
        string? username = null,
        Guid? actorUserId = null,
        string? details = null,
        string? failureReason = null,
        string? oldValue = null,
        string? newValue = null,
        CancellationToken cancellationToken = default)
    {
        var httpContext = httpContextAccessor.HttpContext;
        var correlationId = Guid.TryParse(httpContext?.TraceIdentifier, out var traceId)
            ? traceId
            : Guid.NewGuid();

        context.UserLogs.Add(new UserLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            ActorUserId = actorUserId,
            Username = Truncate(username?.Trim(), 100) ?? string.Empty,
            EventType = Truncate(eventType, 50) ?? throw new ArgumentException("Event type is required.", nameof(eventType)),
            IsSuccessful = isSuccessful,
            OccurredAt = DateTime.UtcNow,
            IpAddress = Truncate(httpContext?.Connection.RemoteIpAddress?.ToString(), 64),
            UserAgent = Truncate(httpContext?.Request.Headers.UserAgent.ToString(), 1000),
            Application = "AfifeAdmin",
            Details = Truncate(details, 2000),
            FailureReason = Truncate(failureReason, 500),
            OldValue = oldValue,
            NewValue = newValue,
            CorrelationId = correlationId,
            IsPublished = true
        });

        await context.SaveChangesAsync(cancellationToken);
    }

    private static string? Truncate(string? value, int maximumLength) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Length <= maximumLength ? value : value[..maximumLength];
}
