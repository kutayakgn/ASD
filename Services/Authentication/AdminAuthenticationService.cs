using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Services.Audit;

namespace YKBAfife.Services.Authentication;

public sealed class AdminAuthenticationService(
    AfifeContext context,
    IUserActivityLogger activityLogger,
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
                && x.IsActive
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
            await activityLogger.LogAsync(
                UserActivityTypes.LoginFailed,
                false,
                user?.Id,
                normalizedUsername,
                failureReason: "Kullan\u0131c\u0131 ad\u0131 veya \u015fifre hatal\u0131.",
                cancellationToken: cancellationToken);
            return null;
        }

        await activityLogger.LogAsync(
            UserActivityTypes.LoginSucceeded,
            true,
            user.Id,
            user.Username,
            details: "Y\u00f6netim paneline ba\u015far\u0131l\u0131 giri\u015f yap\u0131ld\u0131.",
            cancellationToken: cancellationToken);

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
            x => x.Id == userId && x.IsPublished && x.IsActive && x.RoleCode == CoordinatorRoleCode,
            cancellationToken);

        if (user is null)
        {
            await activityLogger.LogAsync(
                UserActivityTypes.PasswordChangeFailed,
                false,
                userId,
                actorUserId: userId,
                failureReason: "Kullan\u0131c\u0131 bulunamad\u0131 veya aktif de\u011fil.",
                cancellationToken: cancellationToken);
            return ChangePasswordResult.UserNotFound;
        }

        if (!PasswordHashHelper.VerifyPassword(currentPassword, user.PasswordHash))
        {
            logger.LogWarning("Failed password change attempt for user {UserId}.", userId);
            await activityLogger.LogAsync(
                UserActivityTypes.PasswordChangeFailed,
                false,
                user.Id,
                user.Username,
                user.Id,
                failureReason: "Mevcut \u015fifre hatal\u0131.",
                cancellationToken: cancellationToken);
            return ChangePasswordResult.CurrentPasswordIncorrect;
        }

        user.PasswordHash = PasswordHashHelper.HashPassword(newPassword);
        user.UpdatedAt = DateTime.UtcNow;
        user.UpdatedBy = userId;
        await context.SaveChangesAsync(cancellationToken);
        await activityLogger.LogAsync(
            UserActivityTypes.PasswordChanged,
            true,
            user.Id,
            user.Username,
            user.Id,
            details: "Kullan\u0131c\u0131 \u015fifresini de\u011fi\u015ftirdi.",
            cancellationToken: cancellationToken);

        return ChangePasswordResult.Success;
    }
}