namespace YKBAfife.Models.Components;

public sealed class LazySearchSelectViewModel
{
    public string Id { get; init; } = string.Empty;
    public string InputName { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public string Placeholder { get; init; } = string.Empty;
    public string SearchPlaceholder { get; init; } = "Ara";
    public string Endpoint { get; init; } = string.Empty;
    public Guid? SelectedValue { get; init; }
    public string SelectedText { get; init; } = string.Empty;
    public bool IsRequired { get; init; }
}
