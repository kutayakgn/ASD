namespace YKBAfife.Models.Components;

public sealed class ComplexTableViewModel
{
    public string Id { get; init; } = $"complex-table-{Guid.NewGuid():N}";
    public string ControllerName { get; init; } = string.Empty;
    public string ActionName { get; init; } = "Index";
    public string DataActionName { get; init; } = string.Empty;
    public string CurrentTabKey { get; init; } = string.Empty;
    public string SearchPlaceholder { get; init; } = "Ara";
    public string ExportControllerName { get; init; } = string.Empty;
    public string ExportActionName { get; init; } = string.Empty;
    public string ExportButtonText { get; init; } = "Excel'e Aktar";
    public bool IsExportEnabled { get; init; } = true;
    public bool ShowHeading { get; init; } = true;
    public bool ShowSearch { get; init; } = true;
    public bool ShowColumnHeaders { get; init; } = true;
    public int MinimumTableWidth { get; init; } = 720;
    public IReadOnlyDictionary<string, string?> AdditionalRouteValues { get; init; } =
        new Dictionary<string, string?>();
    public IReadOnlyList<ComplexTableTabViewModel> Tabs { get; init; } = [];
    public IReadOnlyList<ComplexTableSummarySegmentViewModel> SummaryContent { get; init; } = [];
}

public sealed class ComplexTableTabViewModel
{
    public string Key { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = string.Empty;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int PageSize { get; init; } = 10;
    public int TotalCount { get; init; }
    public string EmptyMessage { get; init; } = "Kayıt bulunamadı.";
    public IReadOnlyList<ComplexTableColumnViewModel> Columns { get; init; } = [];
    public IReadOnlyList<ComplexTableRowViewModel> Rows { get; init; } = [];
    public IReadOnlyList<ComplexTableHeaderActionViewModel> HeaderActions { get; init; } = [];

    public int TotalPages => Math.Max(1, (int)Math.Ceiling(TotalCount / (double)Math.Max(1, PageSize)));
}

public sealed class ComplexTableColumnViewModel
{
    public string Title { get; init; } = string.Empty;
    public string Key { get; init; } = string.Empty;
    public bool IsSortable { get; init; } = true;
    public int ColWidth { get; init; } = 100;
    public string CssClass { get; init; } = string.Empty;
}

public sealed class ComplexTableRowViewModel
{
    public string Id { get; init; } = string.Empty;
    public string Link { get; init; } = string.Empty;
    public IReadOnlyList<ComplexTableCellViewModel> Cells { get; init; } = [];
}

public sealed class ComplexTableCellViewModel
{
    public string Content { get; init; } = string.Empty;
    public bool IsHtml { get; init; }
    public string CssClass { get; init; } = string.Empty;
    public string Link { get; init; } = string.Empty;
    public string ModalUrl { get; init; } = string.Empty;
    public string AccessibleLabel { get; init; } = string.Empty;
}

public sealed class ComplexTableSummarySegmentViewModel
{
    public string Text { get; init; } = string.Empty;
    public bool IsEmphasized { get; init; }
    public string CssClass { get; init; } = string.Empty;
}
public sealed class ComplexTableHeaderActionViewModel
{
    public string Text { get; init; } = string.Empty;
    public string Link { get; init; } = string.Empty;
    public string CssClass { get; init; } = string.Empty;
}