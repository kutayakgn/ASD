using System.Collections;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace YKBAfife.Services.Security;

public sealed class UnsafeInputValidationFilter(IModelMetadataProvider metadataProvider) : IAsyncActionFilter
{
    private const string ErrorMessage =
        "Güvenlik nedeniyle HTML, script veya çalıştırılabilir içerik gönderilemez.";

    private static readonly Regex ExecutableContentPattern = new(
        @"(?:javascript\s*:|vbscript\s*:|data\s*:\s*text/html|on[a-z]+\s*=|<\s*/?\s*(?:script|iframe|object|embed|svg|math|style|link|meta|base|form|input|button|video|audio|img)\b)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled,
        TimeSpan.FromMilliseconds(100));

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var request = context.HttpContext.Request;
        var hasUnsafeRequestValue = request.Query.Any(item =>
                IsUnsafe(item.Key) ||
                item.Value.Any(value => IsUnsafe(value ?? string.Empty))) ||
            request.RouteValues.Any(item =>
                IsUnsafe(item.Key) || IsUnsafe(Convert.ToString(item.Value) ?? string.Empty));

        if (!hasUnsafeRequestValue && request.HasFormContentType)
        {
            var form = await request.ReadFormAsync(context.HttpContext.RequestAborted);
            var passwordFields = BoundPasswordFields(context, form);
            hasUnsafeRequestValue = form.Any(item =>
                IsUnsafe(item.Key) ||
                (!passwordFields.Contains(item.Key) &&
                 item.Value.Any(value => IsUnsafe(value ?? string.Empty))));
        }

        var visited = new HashSet<object>(ReferenceEqualityComparer.Instance);
        if (hasUnsafeRequestValue ||
            context.ActionArguments.Values.Any(value => ContainsUnsafeInput(value, visited, 0)))
        {
            context.ModelState.AddModelError(string.Empty, ErrorMessage);
            context.Result = new BadRequestObjectResult(new { message = ErrorMessage });
            return;
        }

        await next();
    }

    private bool ContainsUnsafeInput(
        object? value,
        ISet<object> visited,
        int depth)
    {
        if (value is null || depth > 8) return false;
        if (value is string text) return IsUnsafe(text);
        if (value is IFormFile) return false;
        if (value is JsonElement json) return ContainsUnsafeJson(json);

        var type = value.GetType();
        if (type.IsPrimitive || type.IsEnum ||
            value is decimal or DateTime or DateOnly or TimeOnly or TimeSpan or Guid or
            CancellationToken)
        {
            return false;
        }

        if (!type.IsValueType && !visited.Add(value)) return false;

        if (value is IEnumerable values)
        {
            foreach (var item in values)
            {
                if (ContainsUnsafeInput(item, visited, depth + 1)) return true;
            }
            return false;
        }

        foreach (var property in type.GetProperties(BindingFlags.Instance | BindingFlags.Public))
        {
            if (!property.CanRead || property.GetIndexParameters().Length != 0) continue;
            var propertyMetadata = metadataProvider.GetMetadataForType(type).Properties
                .FirstOrDefault(item => item.PropertyName == property.Name);
            // Passwords are opaque credentials. Their exact characters are
            // verified/hashed, never interpreted as HTML or normalized here.
            if (IsBoundPassword(propertyMetadata)) continue;
            object? propertyValue;
            try
            {
                propertyValue = property.GetValue(value);
            }
            catch (TargetInvocationException)
            {
                continue;
            }

            if (ContainsUnsafeInput(propertyValue, visited, depth + 1)) return true;
        }

        return false;
    }

    private HashSet<string> BoundPasswordFields(ActionExecutingContext context, IFormCollection form)
    {
        var fields = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var argument in context.ActionArguments)
        {
            if (argument.Value is null) continue;
            var parameter = context.ActionDescriptor.Parameters.FirstOrDefault(item => item.Name == argument.Key);
            if (parameter?.BindingInfo?.BindingSource is { } source &&
                !source.CanAcceptDataFrom(BindingSource.Form)) continue;

            var explicitPrefix = parameter?.BindingInfo?.BinderModelName;
            var candidatePrefix = explicitPrefix ?? argument.Key;
            // MVC uses the parameter prefix when present, otherwise it binds a
            // top-level form model from unprefixed property names.
            var usesPrefix = explicitPrefix is not null || form.Keys.Any(key =>
                key.Equals(candidatePrefix, StringComparison.OrdinalIgnoreCase) ||
                key.StartsWith(candidatePrefix + ".", StringComparison.OrdinalIgnoreCase) ||
                key.StartsWith(candidatePrefix + "[", StringComparison.OrdinalIgnoreCase));
            CollectPasswordFields(argument.Value, usesPrefix ? candidatePrefix : string.Empty,
                fields, new HashSet<object>(ReferenceEqualityComparer.Instance), 0);
        }
        return fields;
    }

    private void CollectPasswordFields(object? value, string prefix,
        ISet<string> fields, ISet<object> visited, int depth)
    {
        if (value is null || depth > 8 || value is string or IFormFile or JsonElement) return;
        var type = value.GetType();
        if (type.IsPrimitive || type.IsEnum || value is decimal or DateTime or DateOnly or TimeOnly or TimeSpan or Guid or CancellationToken)
            return;
        if (!type.IsValueType && !visited.Add(value)) return;

        if (value is IEnumerable values)
        {
            var index = 0;
            foreach (var item in values)
                CollectPasswordFields(item, $"{prefix}[{index++}]", fields, visited, depth + 1);
            return;
        }

        foreach (var property in type.GetProperties(BindingFlags.Instance | BindingFlags.Public))
        {
            if (!property.CanRead || property.GetIndexParameters().Length != 0) continue;
            var metadata = metadataProvider.GetMetadataForType(type).Properties
                .FirstOrDefault(item => item.PropertyName == property.Name);
            var name = metadata?.BinderModelName ?? property.Name;
            var path = string.IsNullOrEmpty(prefix) ? name : prefix + "." + name;
            if (IsBoundPassword(metadata))
            {
                fields.Add(path);
                continue;
            }
            try
            {
                CollectPasswordFields(property.GetValue(value), path, fields, visited, depth + 1);
            }
            catch (TargetInvocationException)
            {
                // Match the model inspection behavior for unreadable getters.
            }
        }
    }

    private static bool IsBoundPassword(ModelMetadata? metadata) =>
        metadata is { IsBindingAllowed: true, ModelType: var modelType, DataTypeName: "Password" } &&
        modelType == typeof(string);

    private static bool ContainsUnsafeJson(JsonElement json) => json.ValueKind switch
    {
        JsonValueKind.String => IsUnsafe(json.GetString() ?? string.Empty),
        JsonValueKind.Array => json.EnumerateArray().Any(ContainsUnsafeJson),
        JsonValueKind.Object => json.EnumerateObject().Any(item =>
            IsUnsafe(item.Name) || ContainsUnsafeJson(item.Value)),
        _ => false
    };

    private static bool IsUnsafe(string value)
    {
        var normalized = value.Normalize(NormalizationForm.FormKC);
        for (var pass = 0; pass < 3; pass++)
        {
            var decoded = WebUtility.HtmlDecode(normalized);
            if (decoded == normalized) break;
            normalized = decoded;
        }

        if (normalized.Any(character =>
                char.IsControl(character) && character is not '\r' and not '\n' and not '\t'))
        {
            return true;
        }

        // Yönetim alanlarının hiçbiri HTML kabul etmez. Açılı parantezleri de
        // reddetmek, bilinmeyen/obfuscated etiketlerin saklanmasını önler.
        return normalized.Contains('<') || normalized.Contains('>') ||
               ExecutableContentPattern.IsMatch(normalized);
    }
}
