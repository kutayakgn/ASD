namespace YKBAfife.Models.Components;

public sealed class DatePickerViewModel
{
    public string Id { get; init; } = $"date-picker-{Guid.NewGuid():N}";
    public string InputName { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public DateOnly? Value { get; init; }
    public string ValidationMessage { get; init; } = string.Empty;
    public bool IsRequired { get; init; } = true;
    public bool TrackChanges { get; init; } = true;
}
