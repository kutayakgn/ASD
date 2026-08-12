namespace YKBAfife.Helpers;

public static class CandidateCategoryPolicy
{
    public const int BestPlayCategoryCode = 1001;
    public const int BestDirectorCategoryCode = 1002;

    public static bool IsSystemManaged(int categoryCode) =>
        categoryCode is BestPlayCategoryCode or BestDirectorCategoryCode;
}
