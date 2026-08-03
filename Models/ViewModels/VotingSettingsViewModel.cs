using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class VotingSettingsViewModel
{
    public ComplexTableViewModel SeasonTable { get; init; } = new();
    public ComplexTableViewModel AdditionalVotingTable { get; init; } = new();
}
