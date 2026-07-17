using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class HomeDashboardViewModel
{
    public ComplexTableViewModel PlayWatchTable { get; init; } = new();
}
