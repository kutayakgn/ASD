using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;

namespace YKBAfife.Services.Authentication;

public sealed class AdminAuthenticationService(
    AfifeContext context,
    ILogger<AdminAuthenticationService> logger) : IAdminAuthenticationService
{
    private const int CoordinatorRoleCode = 1;

    public async Task<AuthenticatedAdmin?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken cancellationToken = default)
    {
        var normalizedUsername = username.Trim();

        var user = await context.Users
            .AsNoTracking()
            .Where(x => x.IsPublished
                && x.RoleCode == CoordinatorRoleCode
                && x.Username == normalizedUsername)
            .Select(x => new
            {
                x.Id,
                x.FirstName,
                x.LastName,
                x.Username,
                x.PasswordHash
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (user is null || !PasswordHashHelper.VerifyPassword(password, user.PasswordHash))
        {
            logger.LogWarning("Failed admin login attempt for username {Username}.", normalizedUsername);
            return null;
        }

        return new AuthenticatedAdmin(
            user.Id,
            $"{user.FirstName} {user.LastName}".Trim(),
            user.Username);
    }

    public async Task<ChangePasswordResult> ChangePasswordAsync(
        Guid userId,
        string currentPassword,
        string newPassword,
        CancellationToken cancellationToken = default)
    {
        var user = await context.Users.FirstOrDefaultAsync(
            x => x.Id == userId && x.IsPublished && x.RoleCode == CoordinatorRoleCode,
            cancellationToken);

        if (user is null)
        {
            return ChangePasswordResult.UserNotFound;
        }

        if (!PasswordHashHelper.VerifyPassword(currentPassword, user.PasswordHash))
        {
            logger.LogWarning("Failed password change attempt for user {UserId}.", userId);
            return ChangePasswordResult.CurrentPasswordIncorrect;
        }

        user.PasswordHash = PasswordHashHelper.HashPassword(newPassword);
        user.UpdatedAt = DateTime.Now;
        user.UpdatedBy = userId;
        await context.SaveChangesAsync(cancellationToken);

        return ChangePasswordResult.Success;
    }
}