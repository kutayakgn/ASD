using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class JuryWatchedPlayComplexTableFactory
{
    private const string TabKey = "watched-plays";

    public static ComplexTableViewModel Create(JuryWatchedPlayTableViewModel report) => new()
    {
        Id = $"jury-watched-plays-{report.JuryId:N}",
        ControllerName = "Management",
        DataActionName = "JuryWatchedPlaysTable",
        CurrentTabKey = TabKey,
        SearchPlaceholder = "Oyun adı ara",
        MinimumTableWidth = 420,
        ExportControllerName = "Management",
        ExportActionName = "ExportJuryWatchedPlays",
        IsExportEnabled = report.TotalCount > 0,
        AdditionalRouteValues = new Dictionary<string, string?>
        {
            ["juryId"] = report.JuryId.ToString()
        },
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "İzlenen Oyunlar",
                Search = report.Search,
                SortBy = JuryWatchedPlaySortColumns.PlayName,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = JuryWatchedPlayTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Jürinin izlediği oyun bulunamadı.",
                Columns =
                [
                    new ComplexTableColumnViewModel
                    {
                        Title = "Oyun Adı",
                        Key = JuryWatchedPlaySortColumns.PlayName,
                        ColWidth = 100
                    }
                ],
                Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"watched-play-{row.PlayId:N}",
                    Cells = [new ComplexTableCellViewModel { Content = row.PlayName }]
                }).ToArray()
            }
        ],
        SummaryContent =
        [
            new ComplexTableSummarySegmentViewModel
            {
                Text = report.TotalCount.ToString(CultureInfo.CurrentCulture),
                IsEmphasized = true
            },
             new() { Text = " kayıt", IsEmphasized = true },
                new() { Text = " bulundu." }
        ]
    };
}
