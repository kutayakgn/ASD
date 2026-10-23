using YKBAfife.Models.Entities;

namespace YKBAfife.Helpers;

public static class CandidateCategoryPolicy
{
    private static readonly int[] PreviousProductionVersionExcludedCodes = [1002, 1007, 1008, 1009, 1010, 1011];

    public const int BestPlayCategoryCode = 1001;
    public const int BestDirectorCategoryCode = 1002;
    public const int BestActressCategoryCode = 1003;
    public const int BestActorCategoryCode = 1004;
    public const int BestSupportingActressCategoryCode = 1005;
    public const int BestSupportingActorCategoryCode = 1006;

    public static bool IsSystemManaged(int categoryCode) =>
        categoryCode is BestPlayCategoryCode or BestDirectorCategoryCode;

    public static bool IsExcludedForPreviousProductionVersion(int categoryCode) =>
        PreviousProductionVersionExcludedCodes.Contains(categoryCode);

    public static bool IsAllowedForProductionVersion(int categoryCode, bool previousProductionVersion) =>
        !previousProductionVersion || !IsExcludedForPreviousProductionVersion(categoryCode);

    public static IQueryable<PlayAwardCategory> WhereAllowedForProductionVersion(
        this IQueryable<PlayAwardCategory> candidates) =>
        candidates.Where(candidate => candidate.Play.SourceForm == null ||
            !candidate.Play.SourceForm.PreviousProductionVersion ||
            !PreviousProductionVersionExcludedCodes.Contains(candidate.AwardCategoryCode));

    public static bool SupportsRoleAndPhoto(int categoryCode) =>
        categoryCode is BestActressCategoryCode or
            BestActorCategoryCode or
            BestSupportingActressCategoryCode or
            BestSupportingActorCategoryCode;
}
