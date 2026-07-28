using System.Data;
using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace YKBAfife.Services.Audit;

public sealed class AdminAuditConnectionInterceptor(
    IHttpContextAccessor httpContextAccessor) : DbConnectionInterceptor
{
    private const string SessionContextCommand = """
        EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=@CorrelationId;
        EXEC sys.sp_set_session_context @key=N'AdminUserId', @value=@UserId;
        EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=@Username;
        EXEC sys.sp_set_session_context @key=N'AdminIpAddress', @value=@IpAddress;
        EXEC sys.sp_set_session_context @key=N'AdminUserAgent', @value=@UserAgent;
        EXEC sys.sp_set_session_context @key=N'AdminHttpMethod', @value=@HttpMethod;
        EXEC sys.sp_set_session_context @key=N'AdminRequestPath', @value=@RequestPath;
        EXEC sys.sp_set_session_context @key=N'AdminController', @value=@ControllerName;
        EXEC sys.sp_set_session_context @key=N'AdminAction', @value=@ActionName;
        EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=@OperationName;
        EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=N'AfifeAdmin';
        """;

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        SetSessionContext(connection);
        base.ConnectionOpened(connection, eventData);
    }

    public override async Task ConnectionOpenedAsync(
        DbConnection connection,
        ConnectionEndEventData eventData,
        CancellationToken cancellationToken = default)
    {
        await SetSessionContextAsync(connection, cancellationToken);
        await base.ConnectionOpenedAsync(connection, eventData, cancellationToken);
    }

    private void SetSessionContext(DbConnection connection)
    {
        using var command = CreateCommand(connection);
        command.ExecuteNonQuery();
    }

    private async Task SetSessionContextAsync(
        DbConnection connection,
        CancellationToken cancellationToken)
    {
        await using var command = CreateCommand(connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private DbCommand CreateCommand(DbConnection connection)
    {
        var request = AdminAuditRequestContext.FromHttpContext(httpContextAccessor.HttpContext);
        var command = connection.CreateCommand();
        command.CommandText = SessionContextCommand;
        AddParameter(command, "@CorrelationId", request.CorrelationId.ToString());
        AddParameter(command, "@UserId", request.UserId?.ToString());
        AddParameter(command, "@Username", request.Username);
        AddParameter(command, "@IpAddress", request.IpAddress);
        AddParameter(command, "@UserAgent", request.UserAgent);
        AddParameter(command, "@HttpMethod", request.HttpMethod);
        AddParameter(command, "@RequestPath", request.RequestPath);
        AddParameter(command, "@ControllerName", request.ControllerName);
        AddParameter(command, "@ActionName", request.ActionName);
        AddParameter(command, "@OperationName", request.OperationName);
        return command;
    }

    private static void AddParameter(DbCommand command, string name, string? value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.DbType = DbType.String;
        parameter.Value = value is null ? DBNull.Value : value;
        command.Parameters.Add(parameter);
    }
}
