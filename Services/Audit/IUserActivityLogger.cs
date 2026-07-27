namespace YKBAfife.Services.Audit;

public interface IUserActivityLogger
{
    Task LogAsync(
        string eventType,
        bool isSuccessful,
        Guid? userId = null,
        string? username = null,
        Guid? actorUserId = null,
        string? details = null,
        string? failureReason = null,
        string? oldValue = null,
        string? newValue = null,
        CancellationToken cancellationToken = default);
}

public static class UserActivityTypes
{
    public const string LoginSucceeded = "LoginSucceeded";
    public const string LoginFailed = "LoginFailed";
    public const string Logout = "Logout";
    public const string PasswordChanged = "PasswordChanged";
    public const string PasswordChangeFailed = "PasswordChangeFailed";
    public const string EmailChanged = "EmailChanged";
    public const string UserCreated = "UserCreated";
    public const string UserUpdated = "UserUpdated";
    public const string UserSoftDeleted = "UserSoftDeleted";
    public const string TicketFeeChanged = "TicketFeeChanged";
    public const string BlacklistCreated = "BlacklistCreated";
    public const string BlacklistSoftDeleted = "BlacklistSoftDeleted";
    public const string JuryVoteReset = "JuryVoteReset";
    public const string PlaySoftDeleted = "PlaySoftDeleted";
}
