using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class BlacklistComplexTableFactory
{
    private const string TabKey = "blacklists";

    public static ComplexTableViewModel Create(BlacklistTableViewModel report) => new()
    {
        Id = "blacklist-table",
        ControllerName = "Management",
        DataActionName = "BlacklistTable",
        CurrentTabKey = TabKey,
        SearchPlaceholder = "Jüri, oyun veya ekleyen ara",
        MinimumTableWidth = 760,
        ExportControllerName = "Management",
        ExportActionName = "ExportBlacklists",
        IsExportEnabled = report.TotalCount > 0,
        IsDeleteColActive = true,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "Blacklists",
                Search = report.Search,
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = BlacklistTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Blacklist kaydı bulunamadı.",
                HeaderActions =
                [
                    new ComplexTableHeaderActionViewModel { Text = "Blacklist Ekle", Link = "/blacklists/ekle" }
                ],
                Columns =
                [
                    new() { Title = "Jüri", Key = BlacklistSortColumns.Jury, ColWidth = 28 },
                    new() { Title = "Oyun", Key = BlacklistSortColumns.Play, ColWidth = 32 },
                    new() { Title = "Eklenme Tarihi", Key = BlacklistSortColumns.CreatedOn, ColWidth = 20 },
                    new() { Title = "Ekleyen", Key = BlacklistSortColumns.CreatedBy, ColWidth = 20 }
                ],
                Rows = report.Rows.Select(CreateRow).ToArray()
            }
        ],
        SummaryContent =
        [
            new ComplexTableSummarySegmentViewModel { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
            new() { Text = " kayıt bulundu." }
        ]
    };

    private static ComplexTableRowViewModel CreateRow(BlacklistRowViewModel row)
    {
        var deleteUrl = $"/blacklists/{row.Id:D}/sil";
        return new ComplexTableRowViewModel
        {
            Id = $"blacklist-{row.Id:N}",
            DeleteUrl = deleteUrl,
            DeleteConfirmMessage = "İlgili blacklist kaydı silinsin mi?",
            DeleteAccessibleLabel = $"{row.JuryName} - {row.PlayName} blacklist kaydını sil",
            Cells =
            [
                Cell(row.JuryName),
                Cell(row.PlayName),
                Cell(row.CreatedOn.ToLocalTime().ToString("dd.MM.yyyy", CultureInfo.CurrentCulture)),
                Cell(row.CreatedByName)
            ]
        };
    }

    private static ComplexTableCellViewModel Cell(string content) => new() { Content = content };
}
