using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class TicketSalesComplexTableFactory
{
    private const string TabKey = "ticket-sales";

    public static ComplexTableViewModel Create(TicketSalesTableViewModel report) => new()
    {
        Id = "ticket-sales-table",
        ControllerName = "Management",
        DataActionName = "TicketSalesTable",
        CurrentTabKey = TabKey,
        SearchPlaceholder = "Jüri veya oyun ara",
        MinimumTableWidth = 1408,
        ExportControllerName = "Management",
        ExportActionName = "ExportTicketSales",
        IsExportEnabled = report.TotalCount > 0,
        IsEditableRows = true,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "Bilet Satışları",
                Search = report.Search,
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = TicketSalesTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Bilet satışı kaydı bulunamadı.",
                Columns =
                [
                    new() { Title = "Jüri", Key = TicketSalesSortColumns.Jury, ColWidth = ComplexTableColumnWidth.Pixels(480) },
                    new() { Title = "Oyun", Key = TicketSalesSortColumns.Play, ColWidth = ComplexTableColumnWidth.Pixels(480) },
                    new() { Title = "Tarih", Key = TicketSalesSortColumns.Date, ColWidth = ComplexTableColumnWidth.Pixels(200) },
                    new() { Title = "Bilet Fiyatı", Key = TicketSalesSortColumns.TicketFee, ColWidth = ComplexTableColumnWidth.Pixels(200) }
                ],
                Rows = report.Rows.Select(row => CreateRow(row)).ToArray()
            }
        ],
        SummaryContent =
        [
            new ComplexTableSummarySegmentViewModel { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
            new() { Text = " kayıt", IsEmphasized = true } , new() { Text = " bulundu." }
        ]
    };

    private static ComplexTableRowViewModel CreateRow(TicketSaleRowViewModel row)
    {
        var editUrl = $"/bilet-satislari/{row.Id:D}/duzenle";
        return new ComplexTableRowViewModel
        {
            Id = $"ticket-sale-{row.Id:N}",
            ModalUrl = editUrl,
            EditModalUrl = editUrl,
            EditAccessibleLabel = $"{row.JuryName} - {row.PlayName} bilet ücretini düzenle",
            Cells =
            [
                Cell(row.JuryName),
                Cell(row.PlayName),
                Cell(row.Date?.ToString("dd.MM.yyyy", CultureInfo.CurrentCulture) ?? "-"),
                Cell($"{decimal.Truncate(row.TicketFee).ToString("N0", CultureInfo.CurrentCulture)} TL")
            ]
        };
    }

    private static ComplexTableCellViewModel Cell(string content) => new() { Content = content };
}
