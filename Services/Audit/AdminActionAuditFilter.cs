using System.Collections;
using System.Reflection;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using YKBAfife.Controllers;

namespace YKBAfife.Services.Audit;

public sealed class AdminActionAuditFilter(
    IAdminActionAuditLogger auditLogger) : IAsyncActionFilter
{
    private static readonly string[] SensitiveNames =
    [
        "password", "sifre", "hash", "token", "secret", "imagedata", "base64"
    ];

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        if (context.Controller is AccountController ||
            !IsMutationAction(context) ||
            HttpMethods.IsGet(context.HttpContext.Request.Method) ||
            HttpMethods.IsHead(context.HttpContext.Request.Method))
        {
            await next();
            return;
        }

        var request = AdminAuditRequestContext.FromHttpContext(context.HttpContext);
        var requestParameters = SanitizeActionArguments(context.ActionArguments);

        try
        {
            var executed = await next();
            var statusCode = ResolveStatusCode(executed, context.HttpContext.Response.StatusCode);
            var failureReason = ResolveFailureReason(context, executed, statusCode);
            if (string.IsNullOrWhiteSpace(failureReason))
            {
                return;
            }

            var details = JsonSerializer.Serialize(new
            {
                HttpStatusCode = statusCode,
                AttemptedValues = requestParameters,
                ValidationErrors = ResolveModelStateErrors(context),
                Result = SanitizeResult(executed.Result)
            });

            await auditLogger.LogAsync(
                request,
                "FailedAction",
                false,
                statusCode,
                details,
                failureReason,
                CancellationToken.None);
        }
        catch (Exception exception)
        {
            var details = JsonSerializer.Serialize(new
            {
                HttpStatusCode = StatusCodes.Status500InternalServerError,
                AttemptedValues = requestParameters,
                ValidationErrors = ResolveModelStateErrors(context),
                Exception = exception.ToString()
            });

            await auditLogger.LogAsync(
                request,
                "FailedAction",
                false,
                StatusCodes.Status500InternalServerError,
                details,
                BuildExceptionChain(exception),
                CancellationToken.None);
            throw;
        }
    }
    private static bool IsMutationAction(ActionExecutingContext context) =>
        context.ActionDescriptor is ControllerActionDescriptor descriptor &&
        descriptor.MethodInfo.IsDefined(typeof(AdminMutationAuditAttribute), inherit: true);

    private static int ResolveStatusCode(ActionExecutedContext executed, int responseStatusCode) =>
        executed.Result switch
        {
            ObjectResult objectResult when objectResult.StatusCode.HasValue => objectResult.StatusCode.Value,
            StatusCodeResult statusCodeResult => statusCodeResult.StatusCode,
            _ => responseStatusCode
        };

    private static string? ResolveFailureReason(
        ActionExecutingContext context,
        ActionExecutedContext executed,
        int statusCode)
    {
        if (executed.Exception is not null)
        {
            return BuildExceptionChain(executed.Exception);
        }

        var modelErrors = ResolveModelStateErrors(context);
        if (modelErrors.Count > 0)
        {
            return string.Join(" | ", modelErrors);
        }

        if (context.Controller is Controller controller &&
            string.Equals(controller.TempData.Peek("GenericPopup.Type")?.ToString(), "fail", StringComparison.OrdinalIgnoreCase))
        {
            return controller.TempData.Peek("GenericPopup.Message")?.ToString()
                ?? "Islem generic hata bildirimiyle sonuclandi.";
        }

        var resultFailure = ReadResultFailure(executed.Result);
        if (!string.IsNullOrWhiteSpace(resultFailure))
        {
            return resultFailure;
        }

        return statusCode >= 400 ? $"HTTP {statusCode}" : null;
    }

    private static IReadOnlyList<string> ResolveModelStateErrors(ActionExecutingContext context) =>
        context.ModelState
            .Where(item => item.Value?.Errors.Count > 0)
            .SelectMany(item => item.Value!.Errors.Select(error =>
                $"{item.Key}: {error.ErrorMessage.NullIfWhiteSpace() ?? error.Exception?.GetBaseException().Message ?? "Gecersiz deger."}"))
            .ToArray();

    private static string? ReadResultFailure(IActionResult? result)
    {
        object? value = result switch
        {
            JsonResult json => json.Value,
            ObjectResult objectResult => objectResult.Value,
            _ => null
        };
        if (value is null) return null;

        var successProperty = value.GetType().GetProperty(
            "success",
            BindingFlags.Instance | BindingFlags.Public | BindingFlags.IgnoreCase);
        if (successProperty?.PropertyType != typeof(bool) ||
            successProperty.GetValue(value) is not false)
        {
            return null;
        }

        return value.GetType().GetProperty(
                   "message",
                   BindingFlags.Instance | BindingFlags.Public | BindingFlags.IgnoreCase)
               ?.GetValue(value)?.ToString()
            ?? "Islem basarisiz sonuclandi.";
    }

    private static object? SanitizeResult(IActionResult? result) => result switch
    {
        JsonResult json => SanitizeValue(json.Value, "result", 0),
        ObjectResult objectResult => SanitizeValue(objectResult.Value, "result", 0),
        RedirectResult redirect => new { redirect.Url },
        RedirectToActionResult redirect => new { redirect.ControllerName, redirect.ActionName, redirect.RouteValues },
        _ => result?.GetType().Name
    };

    private static object SanitizeActionArguments(IDictionary<string, object?> arguments) =>
        arguments.ToDictionary(
            item => item.Key,
            item => SanitizeValue(item.Value, item.Key, 0));

    private static object? SanitizeValue(object? value, string name, int depth)
    {
        if (IsSensitive(name)) return "[REDACTED]";
        if (value is null) return null;
        if (value is CancellationToken) return "[CancellationToken]";
        if (value is IFormFile file)
            return new { file.FileName, file.ContentType, file.Length };
        if (depth >= 4) return $"[{value.GetType().Name}]";

        var type = value.GetType();
        if (type.IsPrimitive || type.IsEnum || value is string || value is decimal ||
            value is Guid || value is DateTime || value is DateOnly || value is TimeOnly)
        {
            return value;
        }

        if (value is IEnumerable enumerable)
        {
            return enumerable.Cast<object?>()
                .Take(50)
                .Select(item => SanitizeValue(item, name, depth + 1))
                .ToArray();
        }

        var result = new Dictionary<string, object?>();
        foreach (var property in type.GetProperties(BindingFlags.Instance | BindingFlags.Public)
                     .Where(property => property.CanRead && property.GetIndexParameters().Length == 0))
        {
            try
            {
                result[property.Name] = SanitizeValue(
                    property.GetValue(value),
                    property.Name,
                    depth + 1);
            }
            catch
            {
                result[property.Name] = "[UNAVAILABLE]";
            }
        }

        return result;
    }

    private static bool IsSensitive(string name) =>
        SensitiveNames.Any(sensitive =>
            name.Contains(sensitive, StringComparison.OrdinalIgnoreCase));

    private static string BuildExceptionChain(Exception exception)
    {
        var messages = new List<string>();
        for (var current = exception; current is not null; current = current.InnerException!)
        {
            messages.Add($"{current.GetType().Name}: {current.Message}");
            if (current.InnerException is null) break;
        }

        return string.Join(" --> ", messages);
    }

}

internal static class AdminAuditStringExtensions
{
    public static string? NullIfWhiteSpace(this string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value;
}