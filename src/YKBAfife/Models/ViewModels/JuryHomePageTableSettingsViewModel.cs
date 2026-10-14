namespace YKBAfife.Models.ViewModels;

public sealed class JuryHomePageTableSettingsRowViewModel
{
    public string ConfigName { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public bool IsEnabled { get; init; }
    public bool IsAvailable { get; init; }
}
