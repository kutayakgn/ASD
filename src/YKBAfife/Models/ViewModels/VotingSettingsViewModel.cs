using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class VotingSettingsViewModel
{
    public ComplexTableViewModel SeasonTable { get; init; } = new();
    public ComplexTableViewModel AdditionalVotingTable { get; init; } = new();
    public ComplexTableViewModel PlayStatusTable { get; init; } = new();
    public ComplexTableViewModel AnnouncementTable { get; init; } = new();
    public ComplexTableViewModel JuryHomePageTable { get; init; } = new();
}
