namespace YKBAfife.Helpers;

public static class CandidateCategoryPolicy
{
    public const int BestPlayCategoryCode = 1001;
    public const int BestDirectorCategoryCode = 1002;
    public const int BestActressCategoryCode = 1003;
    public const int BestActorCategoryCode = 1004;
    public const int BestSupportingActressCategoryCode = 1005;
    public const int BestSupportingActorCategoryCode = 1006;

    public static bool IsSystemManaged(int categoryCode) =>
        categoryCode is BestPlayCategoryCode or BestDirectorCategoryCode;

    public static bool SupportsRoleAndPhoto(int categoryCode) =>
        categoryCode is BestActressCategoryCode or
            BestActorCategoryCode or
            BestSupportingActressCategoryCode or
            BestSupportingActorCategoryCode;
}
