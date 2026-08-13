using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class RankingComplexTableFactory
{
    private static readonly decimal[] SixColumnRankingWidths = [64, 310, 310, 310, 216, 200];

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
            Icon = ConfidenceIcon(row.ConfidenceValue),
            IconAccessibleLabel = row.ConfidenceValue.HasValue ? $"Güven puanı {row.ConfidenceValue}/4" : "Güven puanı yok",
            Cells = CreateCells(row, report)
        }).ToArray();

        return new ComplexTableViewModel
        {
            Id = "rankings-table",
            ControllerName = "Management",
            ActionName = "Rankings",
            DataActionName = "RankingsTable",
            CurrentTabKey = report.Tab,
            ShowSearch = false,
            MinimumTableWidth = 1080,
            IsIconColActive = report.RankingType == RankingTypes.Confidence,
            IconColumnWidth = 48,
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
        RankingTableViewModel report)
    {
        var columns = new List<ComplexTableColumnViewModel>
        {
            new() { Title = "Sıra", Key = "position", ColWidth = 7, ResponsiveWidth = ResponsiveWidth(report, 0), IsSortable = false },
            new() { Title = "Kategori", Key = "category", ColWidth = 17, ResponsiveWidth = ResponsiveWidth(report, 1), IsSortable = false },
            new()
            {
                Title = report.CategoryHasRoleAndPhoto ? "Adı Soyadı" : "Tiyatro Adı",
                Key = "displayName", ColWidth = 21, ResponsiveWidth = ResponsiveWidth(report, 2), IsSortable = false
            },
            new() { Title = "Oyun Adı", Key = "play", ColWidth = 21, ResponsiveWidth = ResponsiveWidth(report, 3), IsSortable = false },
            new() { Title = "Oy Sayısı", Key = "viewCount", ColWidth = 12, ResponsiveWidth = ResponsiveWidth(report, 4), IsSortable = false }
        };
        if (report.RankingType != RankingTypes.Trimmed)
        {
            if (report.Tab != RankingTabs.CategoryArithmetic)
            {
                columns.Add(new ComplexTableColumnViewModel
                {
                    Title = "Varyans", Key = "variance", ColWidth = 10, IsSortable = false
                });
            }

            columns.Add(new ComplexTableColumnViewModel
            {
                Title = report.RankingType == RankingTypes.Confidence ? "Güven Puanı" : "Aritmetik Ortalama",
                Key = "metric", ColWidth = 12,
                ResponsiveWidth = report.Tab == RankingTabs.CategoryArithmetic
                    ? ResponsiveWidth(report, 5)
                    : null,
                IsSortable = false
            });
        }
        else
        {
            columns.Add(new ComplexTableColumnViewModel
            {
                Title = "Trim Ortalama", Key = "metric", ColWidth = 22,
                ResponsiveWidth = ResponsiveWidth(report, 5), IsSortable = false
            });
        }
        return columns;
    }

    private static decimal? ResponsiveWidth(RankingTableViewModel report, int columnIndex) =>
        report.Tab == RankingTabs.CategoryArithmetic ||
        (report.RankingType == RankingTypes.Trimmed &&
         report.Tab is RankingTabs.AllGames or RankingTabs.CategoryTrim)
            ? SixColumnRankingWidths[columnIndex]
            : null;

    private static IReadOnlyList<ComplexTableCellViewModel> CreateCells(
        RankingRowViewModel row,
        RankingTableViewModel report)
    {
        var cells = new List<ComplexTableCellViewModel>
        {
            Cell(row.Position), Cell(row.CategoryName), Cell(row.DisplayName), Cell(row.PlayName),
            new()
            {
                Content = row.ViewCount.ToString(CultureInfo.CurrentCulture),
                ModalUrl = $"/siralamalar/{row.PlayAwardCategoryId}/oylar",
                AccessibleLabel = $"{row.PlayName} oylarını görüntüle"
            }
        };
        if (report.RankingType != RankingTypes.Trimmed &&
            report.Tab != RankingTabs.CategoryArithmetic)
        {
            cells.Add(new ComplexTableCellViewModel
            {
                Content = row.Variance?.ToString("0.000", CultureInfo.CurrentCulture) ?? "-"
            });
        }
        cells.Add(MetricCell(row.MetricValue, report.RankingType));
        return cells;
    }
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

    private static string ConfidenceIcon(int? value) => value switch
    {
        4 or 3 => "/icons/confidence_success.svg",
        2 => "/icons/confidence_flag.svg",
        1 => "/icons/confidence_double_flag.svg",
        _ => string.Empty
    };

    private static ComplexTableCellViewModel MetricCell(double? value, string rankingType) => new()
    {
        Content = value.HasValue
            ? rankingType == RankingTypes.Confidence
                ? $"{Convert.ToInt32(value.Value)}/4"
                : value.Value.ToString("0.00", CultureInfo.CurrentCulture)
            : "-"
    };
}
