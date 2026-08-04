using System.Text.Json;
using System.Text.Json.Nodes;

namespace YKBAfife.Services.Audit;

public static class AuditLogDisplaySanitizer
{
    private static readonly string[] SensitiveNameFragments =
    [
        "password", "sifre", "hash", "token", "secret", "base64", "imagedata"
    ];

    public static string? Sanitize(string? value, string? tableName = null)
    {
        if (string.IsNullOrWhiteSpace(value)) return value;

        try
        {
            var node = JsonNode.Parse(value);
            if (node is null) return value;
            Redact(node, tableName);
            return node.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
        }
        catch (JsonException)
        {
            return value.Length > 100_000 ? value[..100_000] + "\n[TRUNCATED FOR DISPLAY]" : value;
        }
    }

    private static void Redact(JsonNode node, string? tableName)
    {
        if (node is JsonObject jsonObject)
        {
            foreach (var property in jsonObject.ToArray())
            {
                if (IsSensitive(property.Key, tableName))
                {
                    jsonObject[property.Key] = "[REDACTED]";
                }
                else if (property.Value is not null)
                {
                    Redact(property.Value, tableName);
                }
            }
            return;
        }

        if (node is JsonArray jsonArray)
        {
            foreach (var item in jsonArray)
            {
                if (item is not null) Redact(item, tableName);
            }
        }
    }

    private static bool IsSensitive(string name, string? tableName)
    {
        var normalized = name.Replace("_", string.Empty, StringComparison.Ordinal).ToLowerInvariant();
        if (SensitiveNameFragments.Any(normalized.Contains)) return true;
        return string.Equals(tableName, "Images", StringComparison.OrdinalIgnoreCase) &&
            string.Equals(normalized, "data", StringComparison.OrdinalIgnoreCase);
    }
}