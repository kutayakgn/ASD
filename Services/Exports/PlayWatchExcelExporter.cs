using ClosedXML.Excel;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public sealed class PlayWatchExcelExporter : IPlayWatchExcelExporter
{
    public byte[] Export(IReadOnlyList<PlayWatchRowViewModel> rows, string worksheetTitle)
    {
        using var workbook = new XLWorkbook();
        var worksheet = workbook.Worksheets.Add("Oyun İzlenmeleri");

        worksheet.Cell(1, 1).Value = worksheetTitle;
        worksheet.Range(1, 1, 1, 2).Merge();
        worksheet.Cell(1, 1).Style.Font.Bold = true;
        worksheet.Cell(1, 1).Style.Font.FontSize = 16;
        worksheet.Cell(1, 1).Style.Font.FontColor = XLColor.White;
        worksheet.Cell(1, 1).Style.Fill.BackgroundColor = XLColor.FromHtml("#17223B");

        worksheet.Cell(3, 1).Value = "Oyun Adı";
        worksheet.Cell(3, 2).Value = "İzlenme Sayısı";

        for (var index = 0; index < rows.Count; index++)
        {
            var rowNumber = index + 4;
            worksheet.Cell(rowNumber, 1).Value = rows[index].PlayName;
            worksheet.Cell(rowNumber, 2).Value = rows[index].ViewCount;
        }

        var lastDataRow = Math.Max(4, rows.Count + 3);
        var tableRange = worksheet.Range(3, 1, lastDataRow, 2);
        var table = tableRange.CreateTable("OyunIzlenmeRaporu");
        table.Theme = XLTableTheme.TableStyleMedium2;

        var summaryRow = lastDataRow + 2;
        worksheet.Cell(summaryRow, 1).Value = $"Toplam {rows.Count} oyun";
        worksheet.Cell(summaryRow, 2).Value = rows.Sum(x => x.ViewCount);
        worksheet.Cell(summaryRow, 2).Style.NumberFormat.Format = "0 \"izlenme\"";
        worksheet.Range(summaryRow, 1, summaryRow, 2).Style.Font.Bold = true;

        worksheet.SheetView.FreezeRows(3);
        worksheet.Column(1).Width = 45;
        worksheet.Column(2).Width = 20;
        worksheet.Column(2).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }
}
