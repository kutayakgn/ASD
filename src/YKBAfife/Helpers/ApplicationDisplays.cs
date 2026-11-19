using System.Buffers;
using System.Globalization;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Unicode;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Helpers;

public static class ApplicationDisplays
{
    private static readonly string[] DateFormats = ["yyyy-MM-dd", "dd/MM/yyyy"];

    public static bool TryParse(string? raw, out List<ApplicationDisplayViewModel> rows)
    {
        rows = [];
        if (!TryReadStoredRows(raw, out var storedRows)) return false;
        rows = storedRows.Select(row => row.Model).ToList();
        return true;
    }

    public static List<ApplicationDisplayViewModel> InDisplayOrder(IEnumerable<ApplicationDisplayViewModel> rows) =>
        rows.OrderBy(row => row.Date)
            .ThenBy(row => row.Time ?? TimeOnly.MinValue)
            .ToList();

    public static bool TrySerialize(
        string? originalRaw,
        IReadOnlyList<ApplicationDisplayViewModel> rows,
        out string json,
        out string? error)
    {
        json = originalRaw ?? "[]";
        error = null;
        if (!TryReadStoredRows(originalRaw, out var storedRows))
        {
            error = "Mevcut gösterim bilgileri tanınamadığı için değiştirilemedi.";
            return false;
        }

        if (rows is null)
        {
            error = "Gösterim bilgileri geçersizdir.";
            return false;
        }

        var originalIndices = new HashSet<int>();
        foreach (var row in rows)
        {
            if (row is null || string.IsNullOrWhiteSpace(row.Location) || !row.Date.HasValue)
            {
                error = "Her gösterim için yer ve tarih giriniz.";
                return false;
            }

            if (row.Time.HasValue && row.Time.Value.Ticks % TimeSpan.TicksPerMinute != 0)
            {
                error = "Gösterim saatini saat ve dakika olarak giriniz.";
                return false;
            }

            if (row.OriginalIndex is int originalIndex &&
                (originalIndex < 0 || originalIndex >= storedRows.Count || !originalIndices.Add(originalIndex)))
            {
                error = "Gösterim kaydı değişmiş veya geçersizdir. Sayfayı yenileyip tekrar deneyiniz.";
                return false;
            }
        }

        if (rows.Count == storedRows.Count && rows.All(row =>
                row.OriginalIndex is int originalIndex && SameValues(row, storedRows[originalIndex].Model)))
        {
            // Display sorting does not change the original payload, including its order and unmapped properties.
            return true;
        }

        var buffer = new ArrayBufferWriter<byte>();
        using (var writer = new Utf8JsonWriter(buffer, new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.Create(UnicodeRanges.All)
        }))
        {
            writer.WriteStartArray();
            foreach (var row in rows)
            {
                writer.WriteStartObject();
                if (row.OriginalIndex is int originalIndex)
                    WriteExistingRow(writer, storedRows[originalIndex], row);
                else
                {
                    writer.WriteString("Location", row.Location);
                    writer.WriteString("Date", row.Date!.Value.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture));
                    if (row.Time.HasValue)
                        writer.WriteString("Time", row.Time.Value.ToString("HH:mm", CultureInfo.InvariantCulture));
                }
                writer.WriteEndObject();
            }
            writer.WriteEndArray();
        }

        json = Encoding.UTF8.GetString(buffer.WrittenSpan);
        return true;
    }

    private static void WriteExistingRow(
        Utf8JsonWriter writer,
        StoredRow stored,
        ApplicationDisplayViewModel row)
    {
        foreach (var property in stored.Json.EnumerateObject())
        {
            if (property.Name == stored.LocationName && row.Location != stored.Model.Location)
                writer.WriteString(property.Name, row.Location);
            else if (property.Name == stored.DateName && row.Date != stored.Model.Date)
                writer.WriteString(property.Name, row.Date!.Value.ToString(stored.DateFormat, CultureInfo.InvariantCulture));
            else if (property.Name == stored.TimeName && row.Time != stored.Model.Time)
            {
                if (row.Time.HasValue)
                    writer.WriteString(property.Name, row.Time.Value.ToString("HH:mm", CultureInfo.InvariantCulture));
            }
            else
            {
                writer.WritePropertyName(property.Name);
                writer.WriteRawValue(property.Value.GetRawText(), skipInputValidation: true);
            }
        }

        if (stored.TimeName is null && row.Time.HasValue)
            writer.WriteString("Time", row.Time.Value.ToString("HH:mm", CultureInfo.InvariantCulture));
    }

    private static bool SameValues(ApplicationDisplayViewModel left, ApplicationDisplayViewModel right) =>
        left.Location == right.Location && left.Date == right.Date && left.Time == right.Time;

    private static bool TryReadStoredRows(string? raw, out List<StoredRow> rows)
    {
        rows = [];
        if (string.IsNullOrWhiteSpace(raw)) return true;

        try
        {
            using var document = JsonDocument.Parse(raw);
            if (document.RootElement.ValueKind != JsonValueKind.Array) return false;

            foreach (var element in document.RootElement.EnumerateArray())
            {
                if (!TryReadStoredRow(element, rows.Count, out var row))
                {
                    rows = [];
                    return false;
                }
                rows.Add(row!);
            }
            return true;
        }
        catch (JsonException)
        {
            rows = [];
            return false;
        }
    }

    private static bool TryReadStoredRow(JsonElement element, int index, out StoredRow? stored)
    {
        stored = null;
        if (element.ValueKind != JsonValueKind.Object) return false;

        JsonProperty? locationProperty = null;
        JsonProperty? dateProperty = null;
        JsonProperty? timeProperty = null;
        foreach (var property in element.EnumerateObject())
        {
            if (property.Name.Equals("Location", StringComparison.OrdinalIgnoreCase) ||
                property.Name.Equals("Stage", StringComparison.OrdinalIgnoreCase))
            {
                if (locationProperty.HasValue) return false;
                locationProperty = property;
            }
            else if (property.Name.Equals("Date", StringComparison.OrdinalIgnoreCase))
            {
                if (dateProperty.HasValue) return false;
                dateProperty = property;
            }
            else if (property.Name.Equals("Time", StringComparison.OrdinalIgnoreCase))
            {
                if (timeProperty.HasValue) return false;
                timeProperty = property;
            }
        }

        if (locationProperty?.Value.ValueKind != JsonValueKind.String ||
            dateProperty?.Value.ValueKind != JsonValueKind.String) return false;
        var location = locationProperty.Value.Value.GetString();
        var dateText = dateProperty.Value.Value.GetString();
        if (string.IsNullOrWhiteSpace(location)) return false;

        var dateFormat = DateFormats.FirstOrDefault(format =>
            DateOnly.TryParseExact(dateText, format, CultureInfo.InvariantCulture, DateTimeStyles.None, out _));
        if (dateFormat is null) return false;
        var date = DateOnly.ParseExact(dateText!, dateFormat, CultureInfo.InvariantCulture);

        TimeOnly? time = null;
        if (timeProperty.HasValue && timeProperty.Value.Value.ValueKind != JsonValueKind.Null)
        {
            if (timeProperty.Value.Value.ValueKind != JsonValueKind.String) return false;
            var timeText = timeProperty.Value.Value.GetString();
            if (!string.IsNullOrWhiteSpace(timeText))
            {
                if (!TimeOnly.TryParseExact(timeText, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedTime))
                    return false;
                time = parsedTime;
            }
        }

        stored = new StoredRow(new ApplicationDisplayViewModel
        {
            OriginalIndex = index,
            Location = location,
            Date = date,
            Time = time
        }, element.Clone(), locationProperty.Value.Name, dateProperty.Value.Name, timeProperty?.Name, dateFormat);
        return true;
    }

    private sealed record StoredRow(
        ApplicationDisplayViewModel Model,
        JsonElement Json,
        string LocationName,
        string DateName,
        string? TimeName,
        string DateFormat);
}
