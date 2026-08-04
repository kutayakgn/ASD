using YKBAfife.Data;
using YKBAfife.Helpers;
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
        var request = AdminAuditRequestContext.FromHttpContext(httpContextAccessor.HttpContext);
        var effectiveUsername = Truncate(username?.Trim(), 100) ?? Truncate(request.Username, 100) ?? string.Empty;

        context.UserLogs.Add(new UserLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            ActorUserId = actorUserId ?? request.UserId,
            Username = effectiveUsername,
            EventType = Truncate(eventType, 50) ?? throw new ArgumentException("Event type is required.", nameof(eventType)),
            IsSuccessful = isSuccessful,
            OccurredAt = TurkeyTime.Now,
            IpAddress = Truncate(request.IpAddress, 64),
            UserAgent = Truncate(request.UserAgent, 1000),
            Application = "AfifeAdmin",
            Details = Truncate(details, 2000) ?? $"{eventType} olayı kaydedildi.",
            FailureReason = Truncate(failureReason, 500),
            OldValue = oldValue,
            NewValue = newValue,
            CorrelationId = request.CorrelationId,
            IsPublished = true
        });

        await context.SaveChangesAsync(cancellationToken);
    }

    private static string? Truncate(string? value, int maximumLength) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Length <= maximumLength ? value : value[..maximumLength];
}
