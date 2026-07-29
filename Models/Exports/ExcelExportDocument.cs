namespace YKBAfife.Models.Exports;

public sealed class ExcelExportDocument
{
    public string WorksheetName { get; init; } = "Rapor";
    public string Title { get; init; } = string.Empty;
    public string TableName { get; init; } = "RaporTablosu";
    public IReadOnlyList<string> MetadataLines { get; init; } = [];
    public IReadOnlyList<ExcelExportColumn> Columns { get; init; } = [];
    public IReadOnlyList<IReadOnlyList<ExcelExportCell>> Rows { get; init; } = [];
    public IReadOnlyList<string> FooterLines { get; init; } = [];
}

public sealed class ExcelExportColumn
{
    public string Header { get; init; } = string.Empty;
    public double Width { get; init; } = 20;
    public ExcelExportAlignment Alignment { get; init; } = ExcelExportAlignment.Left;
}

public sealed class ExcelExportCell
{
    public object? Value { get; init; }
}

public enum ExcelExportAlignment
{
    Left,
    Center,
    Right
}
