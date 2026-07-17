namespace YKBAfife.Services.Authentication;

public interface IAdminAuthenticationService
{
    Task<AuthenticatedAdmin?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken cancellationToken = default);

    Task<ChangePasswordResult> ChangePasswordAsync(
        Guid userId,
        string currentPassword,
        string newPassword,
        CancellationToken cancellationToken = default);
}

public sealed record AuthenticatedAdmin(Guid UserId, string FullName, string Username);

public enum ChangePasswordResult
{
    Success,
    UserNotFound,
    CurrentPasswordIncorrect
}