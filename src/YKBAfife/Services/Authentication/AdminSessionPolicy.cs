using Microsoft.AspNetCore.Authentication;

namespace YKBAfife.Services.Authentication;

public static class AdminSessionPolicy
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);
    public const string VersionKey = "afife.idle.version";
    public const string SessionIdKey = "afife.idle.id";
    public const string Version = "1";

    public static AuthenticationProperties CreateProperties(DateTimeOffset activityUtc, string? sessionId = null)
    {
        var properties = new AuthenticationProperties
        {
            IsPersistent = true,
            AllowRefresh = true,
            IssuedUtc = activityUtc,
            ExpiresUtc = activityUtc.Add(Lifetime)
        };
        properties.Items[VersionKey] = Version;
        properties.Items[SessionIdKey] = sessionId ?? Guid.NewGuid().ToString("N");
        return properties;
    }

    public static bool TryGetDeadline(AuthenticationProperties properties, out DateTimeOffset deadline)
    {
        deadline = default;
        if (!properties.Items.TryGetValue(VersionKey, out var version) || version != Version ||
            !Guid.TryParseExact(GetSessionId(properties), "N", out _) ||
            properties.IssuedUtc is not { } issued || properties.ExpiresUtc is not { } expires ||
            expires - issued != Lifetime)
            return false;
        deadline = expires;
        return true;
    }

    public static string? GetSessionId(AuthenticationProperties properties) =>
        properties.Items.TryGetValue(SessionIdKey, out var id) ? id : null;

    public static bool IsValid(AuthenticationProperties properties, DateTimeOffset now) =>
        TryGetDeadline(properties, out var deadline) && deadline > now &&
        properties.IssuedUtc <= now.AddMinutes(1);
}
