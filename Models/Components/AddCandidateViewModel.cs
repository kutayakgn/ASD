using Microsoft.AspNetCore.Mvc.Rendering;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Models.Components;

public sealed class AddCandidateViewModel
{
    public required AddCandidateInputModel Input { get; init; }
    public required IReadOnlyList<SelectListItem> Plays { get; init; }
    public required IReadOnlyList<SelectListItem> AwardCategories { get; init; }
    public bool LockPlay { get; init; }
    public string FormAction { get; init; } = string.Empty;
}
