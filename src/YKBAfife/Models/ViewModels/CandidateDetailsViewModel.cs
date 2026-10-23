using YKBAfife.Helpers;

namespace YKBAfife.Models.ViewModels;

public sealed class CandidateDetailsViewModel
{
    public Guid Id { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string PlaySlug { get; init; } = string.Empty;
    public int CategoryCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public string Candidate { get; init; } = string.Empty;
    public string Role { get; init; } = string.Empty;
    public string CurrentState { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime? CreatedAt { get; init; }
    public string? CreatedByName { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public string? UpdatedByName { get; init; }
    public bool HasRoleAndPhoto { get; init; }
    public bool HasPhoto { get; init; }
    public bool PreviousProductionVersion { get; init; }
    public bool CanManage => !CandidateCategoryPolicy.IsSystemManaged(CategoryCode) &&
        CandidateCategoryPolicy.IsAllowedForProductionVersion(CategoryCode, PreviousProductionVersion);
}
