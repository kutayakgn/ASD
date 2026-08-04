using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class ArchiveComparisonComplexTableFactory
{
    private const string TabKey = "seasons";

    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new() { Title = "Sezon", Key = ArchiveComparisonSortColumns.Season, ColWidth = 34 },
        new() { Title = "Oyun Sayısı", Key = ArchiveComparisonSortColumns.PlayCount, ColWidth = 22 },
        new() { Title = "Aktif Oyun Sayısı", Key = ArchiveComparisonSortColumns.ActivePlayCount, ColWidth = 22 },
        new() { Title = "Verilen Oy Sayısı", Key = ArchiveComparisonSortColumns.VoteCount, ColWidth = 22 }
    ];

    public static ComplexTableViewModel Create(ArchiveComparisonTableViewModel report) => new()
    {
        Id = "archive-comparison-table",
        ControllerName = "Management",
        ActionName = "ArchiveComparison",
        DataActionName = "ArchiveComparisonTable",
        CurrentTabKey = TabKey,
        ShowSearch = false,
        MinimumTableWidth = 760,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "Arşiv Karşılaştırma",
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = ArchiveComparisonTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Karşılaştırılacak sezon bulunamadı.",
                Columns = Columns,
                Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"season-{row.Id:N}",
                    Cells =
                    [
                        Cell(row.SeasonName),
                        Cell(row.PlayCount),
                        Cell(row.ActivePlayCount),
                        Cell(row.VoteCount)
                    ]
                }).ToArray()
            }
        ]
    };

    private static ComplexTableCellViewModel Cell(string value) => new() { Content = value };

    private static ComplexTableCellViewModel Cell(int value) => new()
    {
        Content = value.ToString(CultureInfo.CurrentCulture)
    };
}
