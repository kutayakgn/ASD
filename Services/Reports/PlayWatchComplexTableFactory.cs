using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class PlayWatchComplexTableFactory
{
    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new()
        {
            Title = "Oyun Adı",
            Key = PlayWatchSortColumns.PlayName,
            ColWidth = 50
        },
        new()
        {
            Title = "İzlenme Sayısı",
            Key = PlayWatchSortColumns.ViewCount,
            ColWidth = 50,
            CssClass = "watch-count-column"
        }
    ];

    public static ComplexTableViewModel Create(PlayWatchTableViewModel report)
    {
        var rows = report.Rows.Select(row => new ComplexTableRowViewModel
        {
            Id = $"play-{row.PlayId:N}",
            Cells =
            [
                new ComplexTableCellViewModel
                {
                    Content = row.PlayName,
                    CssClass = ""
                },
                new ComplexTableCellViewModel
                {
                    Content = row.ViewCount.ToString(CultureInfo.CurrentCulture),
                    CssClass = ""
                }
            ]
        }).ToArray();

        ComplexTableTabViewModel CreateTab(string key, string title) => new()
        {
            Key = key,
            Title = title,
            Search = report.Search,
            SortBy = report.SortBy,
            SortDirection = report.SortDirection,
            CurrentPage = report.CurrentPage,
            PageSize = PlayWatchTableViewModel.PageSize,
            TotalCount = key == report.CurrentTab ? report.TotalCount : 0,
            EmptyMessage = "Arama ölçütlerine uygun oyun bulunamadı.",
            Columns = Columns,
            Rows = key == report.CurrentTab ? rows : []
        };

        return new ComplexTableViewModel
        {
            Id = "play-watch-table",
           
            ControllerName = "Home",
            ActionName = "Index",
            DataActionName = "PlayWatchTable",
            CurrentTabKey = report.CurrentTab,
            SearchPlaceholder = "Oyun adı ara",
            MinimumTableWidth = 720,
            ExportControllerName = "Home",
            ExportActionName = "Export",
            IsExportEnabled = report.TotalCount > 0,
            Tabs =
            [
                CreateTab(PlayWatchTabs.FourOrMore, "4 Kez ve Üzeri İzlenen Oyunlar"),
                CreateTab(PlayWatchTabs.UnderFour, "4'ten Az İzlenen Oyunlar")
            ],
            SummaryContent =
            [
                new()
                {
                    Text = report.TotalCount.ToString(CultureInfo.CurrentCulture),
                    IsEmphasized = true
                },
                new() { Text = " kayıt bulundu. Bulunan kayıtlarda toplam " },
                new()
                {
                    Text = report.TotalViewCount.ToString(CultureInfo.CurrentCulture),
                    IsEmphasized = true
                },
                new() { Text = " izlenme sayısı mevcut." }
            ]
        };
    }
}
