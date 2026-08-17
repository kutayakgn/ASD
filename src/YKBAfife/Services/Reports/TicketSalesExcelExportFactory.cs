using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;
using YKBAfife.Services.Exports;

namespace YKBAfife.Services.Reports;

public static class TicketSalesExcelExportFactory
{
    public static ExcelExportDocument Create(IReadOnlyList<TicketSaleRowViewModel> rows, TicketSalesTableQuery query) => new()
    {
        WorksheetName = "Bilet Satışları",
        Title = "Bilet Satışları",
        TableName = "BiletSatislari",
        MetadataLines = ExcelExportMetadata.Create(SortLabel(query.SortBy), query.SortDirection,
            [ExcelExportMetadata.SearchFilter(query.Search)]),
        Columns =
        [
            new() { Header = "Jüri", Width = 28 },
            new() { Header = "Oyun", Width = 36 },
            new() { Header = "Tarih", Width = 16 },
            new() { Header = "Bilet Fiyatı", Width = 16, Alignment = ExcelExportAlignment.Right }
        ],
        Rows = rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [
            new() { Value = row.JuryName },
            new() { Value = row.PlayName },
            new() { Value = row.Date },
            new() { Value = decimal.ToInt32(decimal.Truncate(row.TicketFee)) }
        ]).ToArray(),
        FooterLines = [$"Toplam kayıt sayısı: {rows.Count}"]
    };

    private static string SortLabel(string value) => value switch
    {
        TicketSalesSortColumns.Jury => "Jüri",
        TicketSalesSortColumns.Play => "Oyun",
        TicketSalesSortColumns.TicketFee => "Bilet Fiyatı",
        _ => "Tarih"
    };
}
