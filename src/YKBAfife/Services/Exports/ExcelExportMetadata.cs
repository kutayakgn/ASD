namespace YKBAfife.Services.Exports;

public static class ExcelExportMetadata
{
    public static IReadOnlyList<string> Create(
        string? sortLabel = null,
        string? sortDirection = null,
        IEnumerable<string>? filters = null,
        int? exportedPage = null)
    {
        var lines = new List<string>();
        if (!string.IsNullOrWhiteSpace(sortLabel))
        {
            var direction = string.Equals(sortDirection, "desc", StringComparison.OrdinalIgnoreCase)
                ? "Azalan" : "Artan";
            lines.Add($"Sıralama: {sortLabel} ({direction})");
        }
        var activeFilters = filters?.Where(value => !string.IsNullOrWhiteSpace(value)).ToArray() ?? [];
        if (activeFilters.Length > 0) lines.Add($"Filtreler: {string.Join("; ", activeFilters)}");
        if (exportedPage.HasValue) lines.Add($"Aktarılan Sayfa: {exportedPage.Value}");
        return lines;
    }

    public static string SearchFilter(string? search) =>
        string.IsNullOrWhiteSpace(search) ? string.Empty : $"Arama = \"{search.Trim()}\"";
}
