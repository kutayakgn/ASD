using Microsoft.Data.SqlClient;
using YKBAfife.Helpers;

namespace YKBAfife.Services.Audit;

public sealed class AdminActionAuditLogger(
    IConfiguration configuration,
    ILogger<AdminActionAuditLogger> logger) : IAdminActionAuditLogger
{
    public async Task LogAsync(
        AdminAuditRequestContext request,
        string operationType,
        bool isSuccessful,
        int statusCode,
        string? details,
        string? failureReason,
        CancellationToken cancellationToken)
    {
        try
        {
            var connectionString = configuration.GetConnectionString("AfifeConnectionString")
                ?? throw new InvalidOperationException("Connection string 'AfifeConnectionString' was not found.");
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);
            await using var command = connection.CreateCommand();
            command.CommandText = """
                INSERT INTO dbo.AdminLogs
                (
                    Id, CorrelationId, UserId, Username, OperationName, OperationType,
                    SchemaName, TableName, EntityKey, AffectedRowCount, OccurredAt, IpAddress, UserAgent, Application,
                    HttpMethod, RequestPath, ControllerName, ActionName, Source,
                    IsSuccessful, Details, FailureReason, IsPublished
                )
                VALUES
                (
                    @Id, @CorrelationId, @UserId, @Username, @OperationName, @OperationType,
                    @SchemaName, @TableName, @EntityKey, 0, @OccurredAt, @IpAddress, @UserAgent, N'AfifeAdmin',
                    @HttpMethod, @RequestPath, @ControllerName, @ActionName, N'MvcAction',
                    @IsSuccessful, @Details, @FailureReason, 1
                );
                """;
            command.Parameters.AddWithValue("@Id", Guid.NewGuid());
            command.Parameters.AddWithValue("@CorrelationId", request.CorrelationId);
            command.Parameters.AddWithValue("@UserId", (object?)request.UserId ?? DBNull.Value);
            command.Parameters.AddWithValue("@Username", (object?)request.Username ?? DBNull.Value);
            command.Parameters.AddWithValue("@OperationName", request.OperationName);
            command.Parameters.AddWithValue("@OperationType", operationType);
            var tableName = ResolvePrimaryTarget(request.ControllerName, request.ActionName);
            command.Parameters.AddWithValue("@SchemaName", tableName is null ? DBNull.Value : "dbo");
            command.Parameters.AddWithValue("@TableName", (object?)tableName ?? DBNull.Value);
            command.Parameters.AddWithValue("@EntityKey", (object?)request.RequestPath ?? DBNull.Value);
            command.Parameters.AddWithValue("@OccurredAt", TurkeyTime.Now);
            command.Parameters.AddWithValue("@IpAddress", (object?)request.IpAddress ?? DBNull.Value);
            command.Parameters.AddWithValue("@UserAgent", (object?)request.UserAgent ?? DBNull.Value);
            command.Parameters.AddWithValue("@HttpMethod", (object?)request.HttpMethod ?? DBNull.Value);
            command.Parameters.AddWithValue("@RequestPath", (object?)request.RequestPath ?? DBNull.Value);
            command.Parameters.AddWithValue("@ControllerName", (object?)request.ControllerName ?? DBNull.Value);
            command.Parameters.AddWithValue("@ActionName", (object?)request.ActionName ?? DBNull.Value);
            command.Parameters.AddWithValue("@IsSuccessful", isSuccessful);
            command.Parameters.AddWithValue("@Details", (object?)Truncate(details, 16000) ?? $"HTTP {statusCode}");
            command.Parameters.AddWithValue("@FailureReason", (object?)Truncate(failureReason, 2000) ?? DBNull.Value);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Admin action audit log could not be persisted.");
        }
    }

    private static string? ResolvePrimaryTarget(string? controller, string? action)
    {
        if (string.Equals(controller, "AdminManagement", StringComparison.OrdinalIgnoreCase))
            return "Users";
        if (!string.Equals(controller, "Management", StringComparison.OrdinalIgnoreCase) || string.IsNullOrWhiteSpace(action))
            return null;

        return action switch
        {
            "AddJury" or "EditJury" or "DeleteJury" => "Users",
            "AddPlay" or "EditPlay" or "DeletePlay" or "UpdateJuryVotingStatus" or "UpdateKunyeGirisStatus" => "Plays",
            "AddCandidate" or "EditCandidate" or "DeleteCandidate" or "UpdateCandidateStatus" => "PlayAwardCategories",
            "ResetJuryVote" or "ResetJuryVotes" => "JuryVotes",
            "UpdateTicketFee" => "JuryGameTicketFees",
            "AddBlacklist" or "DeleteBlacklist" => "Blacklist",
            "EditApplication" or "DeleteApplication" or "UpdateApplicationStatus" => "Form",
            "AddSeason" or "EditSeason" or "DeleteSeason" => "Seasons",
            "AddAdditionalVoting" or "EditAdditionalVoting" or "DeleteAdditionalVoting" => "AdditionalVotings",
            "EditPlayStatus" => "PlayStatuses",
            "EditAnnouncement" => "Announcements",
            _ => null
        };
    }

    private static string? Truncate(string? value, int maximumLength) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Length <= maximumLength ? value : value[..maximumLength];
}
