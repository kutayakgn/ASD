using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class PlayViewerComplexTableFactory
{
    private const string TabKey = "viewers";

    public static ComplexTableViewModel Create(PlayViewerTableViewModel report)
    {
        return new ComplexTableViewModel
        {
            Id = "play-viewers-table",
            ControllerName = "Home",
            DataActionName = "PlayViewersTable",
            CurrentTabKey = TabKey,
            ShowHeading = false,
            ShowSearch = false,
            ShowColumnHeaders = false,
            MinimumTableWidth = 320,
            ExportControllerName = "Home",
            ExportActionName = "ExportPlayViewers",
            IsExportEnabled = report.TotalCount > 0,
            AdditionalRouteValues = new Dictionary<string, string?>
            {
                ["playId"] = report.PlayId.ToString()
            },
            Tabs =
            [
                new ComplexTableTabViewModel
                {
                    Key = TabKey,
                    Title = "Jüri Üyeleri",
                    CurrentPage = report.CurrentPage,
                    PageSize = PlayViewerTableViewModel.PageSize,
                    TotalCount = report.TotalCount,
                    EmptyMessage = "Bu oyunu izleyen jüri üyesi bulunamadı.",
                    Columns =
                    [
                        new ComplexTableColumnViewModel
                        {
                            Title = "Jüri Adı Soyadı",
                            Key = "fullName",
                            IsSortable = false,
                            ColWidth = 100
                        }
                    ],
                    Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                    {
                        Id = $"jury-{row.JuryId:N}",
                        Cells = [new ComplexTableCellViewModel { Content = row.FullName }]
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
}
