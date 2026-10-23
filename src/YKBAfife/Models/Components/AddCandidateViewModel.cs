using Microsoft.AspNetCore.Mvc.Rendering;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Models.Components;

public sealed class AddCandidateViewModel
{
    public required AddCandidateInputModel Input { get; init; }
    public required IReadOnlyList<SelectListItem> Plays { get; init; }
    public required IReadOnlyList<AddCandidateCategoryOptionViewModel> AwardCategories { get; init; }
    public required IReadOnlyList<AddCandidateReplacementOptionViewModel> ReplacementCandidates { get; init; }
    public IReadOnlySet<Guid> PreviousProductionVersionPlayIds { get; init; } = new HashSet<Guid>();
    public bool LockPlay { get; init; }
    public string FormAction { get; init; } = string.Empty;
}

public sealed class AddCandidateCategoryOptionViewModel
{
    public int CategoryCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public bool MultiCandidate { get; init; }
}

public sealed class AddCandidateReplacementOptionViewModel
{
    public Guid Id { get; init; }
    public int CategoryCode { get; init; }
    public string CandidateName { get; init; } = string.Empty;
    public string? Role { get; init; }
    public int RoleCode { get; init; }
    public string DisplayName { get; init; } = string.Empty;
}
