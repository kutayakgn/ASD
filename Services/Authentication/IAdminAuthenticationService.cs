namespace YKBAfife.Services.Authentication;

public interface IAdminAuthenticationService
{
    Task<AuthenticatedAdmin?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken cancellationToken = default);
}

public sealed record AuthenticatedAdmin(Guid UserId, string FullName, string Username);
