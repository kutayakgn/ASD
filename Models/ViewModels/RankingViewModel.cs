using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class RankingTableQuery
{
    public string Tab { get; set; } = RankingTabs.CategoryTrim;
    public string RankingType { get; set; } = RankingTypes.Trimmed;
    public int CategoryCode { get; set; } = 1001;
    public int PageSize { get; set; } = 10;
    public int Page { get; set; } = 1;
}

public sealed class RankingTableViewModel
{
    public string Tab { get; init; } = RankingTabs.CategoryTrim;
    public string RankingType { get; init; } = RankingTypes.Trimmed;
    public int CategoryCode { get; init; } = 1001;
    public bool CategoryHasRoleAndPhoto { get; init; }
    public int PageSize { get; init; } = 10;
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<RankingCategoryOptionViewModel> Categories { get; init; } = [];
    public IReadOnlyList<RankingRowViewModel> Rows { get; init; } = [];
}

public sealed class RankingRowViewModel
{
    public int Position { get; init; }
    public Guid PlayAwardCategoryId { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public int ViewCount { get; init; }
    public double? MetricValue { get; init; }
}

public sealed class RankingCategoryOptionViewModel
{
    public int CategoryCode { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public bool HasRoleAndPhoto { get; init; }
}

public sealed class RankingsDashboardViewModel
{
    public ComplexTableViewModel Table { get; init; } = new();
}

public static class RankingTabs
{
    public const string CategoryTrim = "category-trim";
    public const string CategoryArithmetic = "category-arithmetic";
    public const string Confidence = "confidence";
    public const string AllGames = "all-games";

    public static readonly IReadOnlyList<string> All =
        [CategoryTrim, CategoryArithmetic, Confidence, AllGames];
}

public static class RankingTypes
{
    public const string Trimmed = "trimmed";
    public const string Arithmetic = "arithmetic";
    public const string Confidence = "confidence";

    public static readonly IReadOnlyList<string> All = [Trimmed, Arithmetic, Confidence];
}
