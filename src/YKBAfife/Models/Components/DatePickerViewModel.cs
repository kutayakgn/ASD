namespace YKBAfife.Models.Components;

public sealed class DatePickerViewModel
{
    public string Id { get; init; } = $"date-picker-{Guid.NewGuid():N}";
    public string InputName { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public DateOnly? Value { get; init; }
    public bool IncludeTime { get; init; }
    public TimeOnly? TimeValue { get; init; }
    public string TimeInputName { get; init; } = string.Empty;
    public string ValidationMessage { get; init; } = string.Empty;
    public bool IsRequired { get; init; } = true;
    public bool AllowClear { get; init; }
    public bool TrackChanges { get; init; } = true;
}
