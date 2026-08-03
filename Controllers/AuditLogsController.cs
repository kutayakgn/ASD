using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Audit;

namespace YKBAfife.Controllers;

[Authorize(Roles = "Coordinator")]
[ResponseCache(Location = ResponseCacheLocation.None, NoStore = true)]
[Route("__afife-audit-console")]
public sealed class AuditLogsController(AfifeContext context) : Controller
{
    [HttpGet("admin-logs")]
    public async Task<IActionResult> AdminLogs(
        [FromQuery] AdminLogFilterViewModel filter,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest("Geçersiz AdminLogs filtre parametresi.");
        Normalize(filter);
        if (filter.OccurredFrom.HasValue && filter.OccurredTo.HasValue && filter.OccurredFrom > filter.OccurredTo)
            return BadRequest("occurredFrom, occurredTo değerinden sonra olamaz.");
        var query = context.AdminLogs.IgnoreQueryFilters().AsNoTracking();

        if (filter.CorrelationId.HasValue)
            query = query.Where(log => log.CorrelationId == filter.CorrelationId.Value);
        if (!string.IsNullOrEmpty(filter.Username))
            query = query.Where(log => log.Username == filter.Username);
        if (!string.IsNullOrEmpty(filter.OperationType))
            query = query.Where(log => log.OperationType == filter.OperationType);
        if (!string.IsNullOrEmpty(filter.SchemaName))
            query = query.Where(log => log.SchemaName == filter.SchemaName);
        if (!string.IsNullOrEmpty(filter.TableName))
            query = query.Where(log => log.TableName == filter.TableName);
        if (filter.OccurredFrom.HasValue)
            query = query.Where(log => log.OccurredAt >= filter.OccurredFrom.Value);
        if (filter.OccurredTo.HasValue)
            query = query.Where(log => log.OccurredAt <= filter.OccurredTo.Value);
        if (!string.IsNullOrEmpty(filter.ActionName))
            query = query.Where(log => log.ActionName == filter.ActionName);

        var totalCount = await query.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)filter.PageSize));
        filter.Page = Math.Clamp(filter.Page, 1, totalPages);
        var logs = await query.OrderByDescending(log => log.OccurredAt).ThenByDescending(log => log.Id)
            .Skip((filter.Page - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToArrayAsync(cancellationToken);

        return View("Index", new AuditLogPageViewModel
        {
            Title = "Admin Logs",
            LogType = "admin",
            BasePath = "/__afife-audit-console/admin-logs",
            AdminFilter = filter,
            Records = logs.Select(ToRecord).ToArray(),
            CurrentPage = filter.Page,
            PageSize = filter.PageSize,
            TotalCount = totalCount,
            PreviousPageUrl = filter.Page > 1 ? BuildPageUrl(filter.Page - 1) : null,
            NextPageUrl = filter.Page < totalPages ? BuildPageUrl(filter.Page + 1) : null
        });
    }

    [HttpGet("user-logs")]
    public async Task<IActionResult> UserLogs(
        [FromQuery] UserLogFilterViewModel filter,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return BadRequest("Geçersiz UsersLog filtre parametresi.");
        Normalize(filter);
        if (filter.OccurredFrom.HasValue && filter.OccurredTo.HasValue && filter.OccurredFrom > filter.OccurredTo)
            return BadRequest("occurredFrom, occurredTo değerinden sonra olamaz.");
        var query = context.UserLogs.IgnoreQueryFilters().AsNoTracking();

        if (filter.UserId.HasValue)
            query = query.Where(log => log.UserId == filter.UserId.Value);
        if (filter.ActorUserId.HasValue)
            query = query.Where(log => log.ActorUserId == filter.ActorUserId.Value);
        if (!string.IsNullOrEmpty(filter.Username))
            query = query.Where(log => log.Username == filter.Username);
        if (filter.OccurredFrom.HasValue)
            query = query.Where(log => log.OccurredAt >= filter.OccurredFrom.Value);
        if (filter.OccurredTo.HasValue)
            query = query.Where(log => log.OccurredAt <= filter.OccurredTo.Value);
        if (!string.IsNullOrEmpty(filter.Application))
            query = query.Where(log => log.Application == filter.Application);
        if (filter.CorrelationId.HasValue)
            query = query.Where(log => log.CorrelationId == filter.CorrelationId.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)filter.PageSize));
        filter.Page = Math.Clamp(filter.Page, 1, totalPages);
        var logs = await query.OrderByDescending(log => log.OccurredAt).ThenByDescending(log => log.Id)
            .Skip((filter.Page - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToArrayAsync(cancellationToken);

        return View("Index", new AuditLogPageViewModel
        {
            Title = "User Logs",
            LogType = "user",
            BasePath = "/__afife-audit-console/user-logs",
            UserFilter = filter,
            Records = logs.Select(ToRecord).ToArray(),
            CurrentPage = filter.Page,
            PageSize = filter.PageSize,
            TotalCount = totalCount,
            PreviousPageUrl = filter.Page > 1 ? BuildPageUrl(filter.Page - 1) : null,
            NextPageUrl = filter.Page < totalPages ? BuildPageUrl(filter.Page + 1) : null
        });
    }

    private string BuildPageUrl(int page)
    {
        var values = Request.Query.ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);
        values["page"] = page.ToString(CultureInfo.InvariantCulture);
        return Request.Path + QueryString.Create(values);
    }

    private static AuditLogRecordViewModel ToRecord(AdminLog log) => new()
    {
        Id = log.Id,
        OccurredAt = log.OccurredAt,
        Fields =
        [
            Field(nameof(log.Id), log.Id),
            Field(nameof(log.CorrelationId), log.CorrelationId),
            Field(nameof(log.UserId), log.UserId),
            Field(nameof(log.Username), log.Username),
            Field(nameof(log.OperationName), log.OperationName),
            Field(nameof(log.OperationType), log.OperationType),
            Field(nameof(log.SchemaName), log.SchemaName),
            Field(nameof(log.TableName), log.TableName),
            Field(nameof(log.EntityKey), AuditLogDisplaySanitizer.Sanitize(log.EntityKey, log.TableName), true),
            Field(nameof(log.OldValues), AuditLogDisplaySanitizer.Sanitize(log.OldValues, log.TableName), true),
            Field(nameof(log.NewValues), AuditLogDisplaySanitizer.Sanitize(log.NewValues, log.TableName), true),
            Field(nameof(log.AffectedRowCount), log.AffectedRowCount),
            Field(nameof(log.OccurredAt), Format(log.OccurredAt)),
            Field(nameof(log.IpAddress), log.IpAddress),
            Field(nameof(log.UserAgent), log.UserAgent, true),
            Field(nameof(log.Application), log.Application),
            Field(nameof(log.HttpMethod), log.HttpMethod),
            Field(nameof(log.RequestPath), log.RequestPath),
            Field(nameof(log.ControllerName), log.ControllerName),
            Field(nameof(log.ActionName), log.ActionName),
            Field(nameof(log.Source), log.Source),
            Field(nameof(log.IsSuccessful), log.IsSuccessful),
            Field(nameof(log.Details), AuditLogDisplaySanitizer.Sanitize(log.Details, log.TableName), true),
            Field(nameof(log.FailureReason), log.FailureReason, true),
            Field(nameof(log.IsPublished), log.IsPublished)
        ]
    };

    private static AuditLogRecordViewModel ToRecord(UserLog log) => new()
    {
        Id = log.Id,
        OccurredAt = log.OccurredAt,
        Fields =
        [
            Field(nameof(log.Id), log.Id),
            Field(nameof(log.UserId), log.UserId),
            Field(nameof(log.ActorUserId), log.ActorUserId),
            Field(nameof(log.Username), log.Username),
            Field(nameof(log.EventType), log.EventType),
            Field(nameof(log.IsSuccessful), log.IsSuccessful),
            Field(nameof(log.OccurredAt), Format(log.OccurredAt)),
            Field(nameof(log.IpAddress), log.IpAddress),
            Field(nameof(log.UserAgent), log.UserAgent, true),
            Field(nameof(log.Application), log.Application),
            Field(nameof(log.Details), AuditLogDisplaySanitizer.Sanitize(log.Details), true),
            Field(nameof(log.FailureReason), log.FailureReason, true),
            Field(nameof(log.OldValue), AuditLogDisplaySanitizer.Sanitize(log.OldValue), true),
            Field(nameof(log.NewValue), AuditLogDisplaySanitizer.Sanitize(log.NewValue), true),
            Field(nameof(log.CorrelationId), log.CorrelationId),
            Field(nameof(log.IsPublished), log.IsPublished)
        ]
    };

    private static AuditLogFieldViewModel Field(string name, object? value, bool isLong = false) => new()
    {
        Name = name,
        Value = value?.ToString(),
        IsLongValue = isLong
    };

    private static string Format(DateTime value) => value.ToString("dd.MM.yyyy HH:mm:ss.fffffff", CultureInfo.InvariantCulture);

    private static void Normalize(AdminLogFilterViewModel filter)
    {
        filter.Username = Normalize(filter.Username);
        filter.OperationType = Normalize(filter.OperationType);
        filter.SchemaName = Normalize(filter.SchemaName);
        filter.TableName = Normalize(filter.TableName);
        filter.ActionName = Normalize(filter.ActionName);
        filter.Page = Math.Max(1, filter.Page);
        filter.PageSize = Math.Clamp(filter.PageSize, 1, 100);
    }

    private static void Normalize(UserLogFilterViewModel filter)
    {
        filter.Username = Normalize(filter.Username);
        filter.Application = Normalize(filter.Application);
        filter.Page = Math.Max(1, filter.Page);
        filter.PageSize = Math.Clamp(filter.PageSize, 1, 100);
    }

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}