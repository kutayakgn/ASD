namespace YKBAfife.Models.Components;

public sealed class ComplexTableViewModel
{
    public string Id { get; init; } = $"complex-table-{Guid.NewGuid():N}";
    public string ControllerName { get; init; } = string.Empty;
    public string ActionName { get; init; } = "Index";
    public string DataActionName { get; init; } = string.Empty;
    public string CurrentTabKey { get; init; } = string.Empty;
    public string SearchPlaceholder { get; init; } = "Ara";
    public int SearchMaxLength { get; init; } = 50;
    public string ExportControllerName { get; init; } = string.Empty;
    public string ExportActionName { get; init; } = string.Empty;
    public string ExportButtonText { get; init; } = "Excel'e Aktar";
    public bool IsExportEnabled { get; init; } = true;
    public bool ShowHeading { get; init; } = true;
    public bool ShowSearch { get; init; } = true;
    public ComplexTableSelectFilterViewModel? SelectFilter { get; init; }
    public IReadOnlyList<ComplexTableSelectFilterViewModel> SelectFilters { get; init; } = [];
    public IReadOnlyList<ComplexTableExportActionViewModel> ExportActions { get; init; } = [];
    public bool ShowColumnHeaders { get; init; } = true;
    public bool IsEditableRows { get; init; }
    public bool IsDeleteColActive { get; init; }
    public bool IsNavigationColActive { get; init; }
    public bool IsIconColActive { get; init; }
    public int EditColumnWidth { get; init; } = 48;
    public int DeleteColumnWidth { get; init; } = 48;
    public int NavigationColumnWidth { get; init; } = 48;
    public int IconColumnWidth { get; init; } = 48;
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
    public decimal ColWidth { get; init; } = 100;
    public string CssClass { get; init; } = string.Empty;
}

public sealed class ComplexTableRowViewModel
{
    public string Id { get; init; } = string.Empty;
    public string Link { get; init; } = string.Empty;
    public string ModalUrl { get; init; } = string.Empty;
    public string EditModalUrl { get; init; } = string.Empty;
    public string EditAccessibleLabel { get; init; } = string.Empty;
    public string DeleteUrl { get; init; } = string.Empty;
    public bool DeleteOnRowClick { get; init; }
    public string DeleteConfirmMessage { get; init; } = string.Empty;
    public string DeleteAccessibleLabel { get; init; } = string.Empty;
    public string NavigationUrl { get; init; } = string.Empty;
    public string NavigationAccessibleLabel { get; init; } = string.Empty;
    public string Icon { get; init; } = string.Empty;
    public string IconAccessibleLabel { get; init; } = string.Empty;
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
    public bool ShowNavigationIcon { get; init; }
    public string ToggleUrl { get; init; } = string.Empty;
    public bool ToggleChecked { get; init; }
    public bool ToggleDisabled { get; init; }
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
    public string Icon { get; init; } = string.Empty;
    public string Link { get; init; } = string.Empty;
    public string CssClass { get; init; } = string.Empty;
    public bool IsButton { get; init; }
    public string PanelTarget { get; init; } = string.Empty;
}
public sealed class ComplexTableSelectFilterViewModel
{
    public string Name { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public string AccessibleLabel { get; init; } = string.Empty;
    public bool ShowLabel { get; init; } = true;
    public string Value { get; init; } = string.Empty;
    public IReadOnlyList<ComplexTableSelectOptionViewModel> Options { get; init; } = [];
}

public sealed class ComplexTableSelectOptionViewModel
{
    public string Value { get; init; } = string.Empty;
    public string Text { get; init; } = string.Empty;
}
public sealed class ComplexTableExportActionViewModel
{
    public string ActionName { get; init; } = string.Empty;
    public string Text { get; init; } = string.Empty;
    public string CssClass { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, string?> RouteValues { get; init; } =
        new Dictionary<string, string?>();
}
