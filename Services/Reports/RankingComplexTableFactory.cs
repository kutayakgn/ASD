using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class RankingComplexTableFactory
{
    private static readonly IReadOnlyDictionary<string, string> TabTitles =
        new Dictionary<string, string>
        {
            [RankingTabs.CategoryTrim] = "Kategori Sıralama Trim",
            [RankingTabs.CategoryArithmetic] = "Kategori Sıralama Aritmetik",
            [RankingTabs.Confidence] = "Güven Sıralaması",
            [RankingTabs.AllGames] = "Tüm Oyunlar"
        };

    public static ComplexTableViewModel Create(RankingTableViewModel report)
    {
        var columns = CreateColumns(report);
        var activeRows = report.Rows.Select(row => new ComplexTableRowViewModel
        {
            Id = $"ranking-{row.PlayAwardCategoryId:N}",
            Cells =
            [
                Cell(row.Position),
                Cell(row.CategoryName),
                Cell(row.DisplayName),
                Cell(row.PlayName),
                Cell(row.ViewCount),
                MetricCell(row.MetricValue, report.RankingType)
            ]
        }).ToArray();

        return new ComplexTableViewModel
        {
            Id = "rankings-table",
            ControllerName = "Management",
            ActionName = "Rankings",
            DataActionName = "RankingsTable",
            CurrentTabKey = report.Tab,
            ShowSearch = false,
            MinimumTableWidth = 980,
            ExportControllerName = "Management",
            IsExportEnabled = report.TotalCount > 0,
            SelectFilters = CreateFilters(report),
            ExportActions =
            [
                new()
                {
                    ActionName = "ExportRankings",
                    Text = "Sayfayı Excele Aktar",
                    CssClass = "ranking-export-page",
                    RouteValues = new Dictionary<string, string?> { ["exportScope"] = "page" }
                },
                new()
                {
                    ActionName = "ExportRankings",
                    Text = "Tüm Tabloyu Excele Aktar",
                    CssClass = "ranking-export-all",
                    RouteValues = new Dictionary<string, string?> { ["exportScope"] = "all" }
                }
            ],
            Tabs = TabTitles.Select(tab => new ComplexTableTabViewModel
            {
                Key = tab.Key,
                Title = tab.Value,
                CurrentPage = tab.Key == report.Tab ? report.CurrentPage : 1,
                PageSize = report.PageSize,
                TotalCount = tab.Key == report.Tab ? report.TotalCount : 0,
                EmptyMessage = "Seçili kategori ve sıralama için kayıt bulunamadı.",
                Columns = columns,
                Rows = tab.Key == report.Tab ? activeRows : []
            }).ToArray()
        };
    }

    private static IReadOnlyList<ComplexTableColumnViewModel> CreateColumns(
        RankingTableViewModel report) =>
    [
        new() { Title = "Sıra", Key = "position", ColWidth = 7, IsSortable = false },
        new() { Title = "Kategori", Key = "category", ColWidth = 18, IsSortable = false },
        new()
        {
            Title = report.CategoryHasRoleAndPhoto ? "Adı Soyadı" : "Tiyatro Adı",
            Key = "displayName",
            ColWidth = 22,
            IsSortable = false
        },
        new() { Title = "Oyun Adı", Key = "play", ColWidth = 22, IsSortable = false },
        new() { Title = "İzlenme Sayısı", Key = "viewCount", ColWidth = 12, IsSortable = false },
        new()
        {
            Title = report.RankingType switch
            {
                RankingTypes.Arithmetic => "Aritmetik Ortalama",
                RankingTypes.Confidence => "Güven Puanı",
                _ => "Trim Ortalama"
            },
            Key = "metric",
            ColWidth = 19,
            IsSortable = false
        }
    ];

    private static IReadOnlyList<ComplexTableSelectFilterViewModel> CreateFilters(
        RankingTableViewModel report)
    {
        var filters = new List<ComplexTableSelectFilterViewModel>();
        if (report.Tab == RankingTabs.AllGames)
        {
            filters.Add(new ComplexTableSelectFilterViewModel
            {
                Name = "RankingType",
                AccessibleLabel = "Sıralama tipi",
                ShowLabel = false,
                Value = report.RankingType,
                Options =
                [
                    Option(RankingTypes.Trimmed, "Tüm Kategori Sıralama Trim"),
                    Option(RankingTypes.Arithmetic, "Tüm Kategori Sıralama Aritmetik"),
                    Option(RankingTypes.Confidence, "Tüm Güven Sıralaması")
                ]
            });
        }

        filters.Add(new ComplexTableSelectFilterViewModel
        {
            Name = "CategoryCode",
            AccessibleLabel = "Ödül kategorisi",
            ShowLabel = false,
            Value = report.CategoryCode.ToString(CultureInfo.InvariantCulture),
            Options = report.Categories.Select(category =>
                Option(category.CategoryCode.ToString(CultureInfo.InvariantCulture), category.CategoryName)).ToArray()
        });
        filters.Add(new ComplexTableSelectFilterViewModel
        {
            Name = "PageSize",
            AccessibleLabel = "Sayfadaki satır sayısı",
            ShowLabel = false,
            Value = report.PageSize.ToString(CultureInfo.InvariantCulture),
            Options =
            [
                Option("5", "5'li Görünüm"),
                Option("10", "10'lu Görünüm"),
                Option("15", "15'li Görünüm"),
                Option("20", "20'li Görünüm")
            ]
        });

        return filters;
    }

    private static ComplexTableSelectOptionViewModel Option(string value, string text) =>
        new() { Value = value, Text = text };

    private static ComplexTableCellViewModel Cell(string value) => new() { Content = value };

    private static ComplexTableCellViewModel Cell(int value) => new()
    {
        Content = value.ToString(CultureInfo.CurrentCulture)
    };

    private static ComplexTableCellViewModel MetricCell(double? value, string rankingType) => new()
    {
        Content = value.HasValue
            ? rankingType == RankingTypes.Confidence
                ? Convert.ToInt32(value.Value).ToString(CultureInfo.CurrentCulture)
                : value.Value.ToString("0.00", CultureInfo.CurrentCulture)
            : "-"
    };
}
