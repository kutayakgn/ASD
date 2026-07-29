using ClosedXML.Excel;
using YKBAfife.Models.Exports;

namespace YKBAfife.Services.Exports;

public sealed class ExcelExporter : IExcelExporter
{
    public byte[] Export(ExcelExportDocument document)
    {
        Validate(document);

        using var workbook = new XLWorkbook();
        var worksheet = workbook.Worksheets.Add(SanitizeWorksheetName(document.WorksheetName));
        var columnCount = document.Columns.Count;

        worksheet.Cell(1, 1).Value = document.Title;
        if (columnCount > 1)
        {
            worksheet.Range(1, 1, 1, columnCount).Merge();
        }

        var titleCell = worksheet.Cell(1, 1);
        titleCell.Style.Font.Bold = true;
        titleCell.Style.Font.FontSize = 16;
        titleCell.Style.Font.FontColor = XLColor.White;
        titleCell.Style.Fill.BackgroundColor = XLColor.FromHtml("#17223B");

        for (var metadataIndex = 0; metadataIndex < document.MetadataLines.Count; metadataIndex++)
        {
            var metadataRow = metadataIndex + 2;
            worksheet.Cell(metadataRow, 1).Value = document.MetadataLines[metadataIndex];
            if (columnCount > 1) worksheet.Range(metadataRow, 1, metadataRow, columnCount).Merge();
            worksheet.Cell(metadataRow, 1).Style.Font.Italic = true;
            worksheet.Cell(metadataRow, 1).Style.Font.FontColor = XLColor.FromHtml("#4B5563");
            worksheet.Cell(metadataRow, 1).Style.Fill.BackgroundColor = XLColor.FromHtml("#F4F2ED");
        }

        var headerRow = document.MetadataLines.Count + 3;
        var firstDataRow = headerRow + 1;
        for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
        {
            var column = document.Columns[columnIndex];
            var excelColumn = columnIndex + 1;
            worksheet.Cell(headerRow, excelColumn).Value = column.Header;
            worksheet.Column(excelColumn).Width = column.Width;
            worksheet.Column(excelColumn).Style.Alignment.Horizontal = ToClosedXmlAlignment(column.Alignment);
        }

        for (var rowIndex = 0; rowIndex < document.Rows.Count; rowIndex++)
        {
            var row = document.Rows[rowIndex];
            for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
            {
                SetCellValue(worksheet.Cell(rowIndex + firstDataRow, columnIndex + 1), row[columnIndex].Value);
            }
        }

        var lastDataRow = Math.Max(firstDataRow, document.Rows.Count + headerRow);
        var table = worksheet.Range(headerRow, 1, lastDataRow, columnCount)
            .CreateTable(SanitizeTableName(document.TableName));
        table.Theme = XLTableTheme.TableStyleMedium2;
        worksheet.SheetView.FreezeRows(headerRow);
        for (var footerIndex = 0; footerIndex < document.FooterLines.Count; footerIndex++)
        {
            var footerRow = lastDataRow + 2 + footerIndex;
            worksheet.Cell(footerRow, 1).Value = document.FooterLines[footerIndex];
            if (columnCount > 1)
            {
                worksheet.Range(footerRow, 1, footerRow, columnCount).Merge();
            }

            worksheet.Cell(footerRow, 1).Style.Font.Bold = true;
            worksheet.Cell(footerRow, 1).Style.Fill.BackgroundColor = XLColor.FromHtml("#F4F2ED");
        }

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static void Validate(ExcelExportDocument document)
    {
        if (document.Columns.Count == 0)
        {
            throw new InvalidOperationException("Excel export must contain at least one column.");
        }

        if (document.Columns.Any(column => string.IsNullOrWhiteSpace(column.Header)))
        {
            throw new InvalidOperationException("Every Excel export column must have a header.");
        }

        if (document.Columns.Select(column => column.Header).Distinct(StringComparer.OrdinalIgnoreCase).Count()
            != document.Columns.Count)
        {
            throw new InvalidOperationException("Excel export column headers must be unique.");
        }

        if (document.Rows.Any(row => row.Count != document.Columns.Count))
        {
            throw new InvalidOperationException("Every Excel export row must match the configured column count.");
        }
    }

    private static void SetCellValue(IXLCell cell, object? value)
    {
        switch (value)
        {
            case null:
                cell.Clear();
                break;
            case int intValue:
                cell.Value = intValue;
                break;
            case long longValue:
                cell.Value = longValue;
                break;
            case decimal decimalValue:
                cell.Value = decimalValue;
                break;
            case double doubleValue:
                cell.Value = doubleValue;
                break;
            case DateTime dateTimeValue:
                cell.Value = dateTimeValue;
                break;
            case bool boolValue:
                cell.Value = boolValue;
                break;
            default:
                cell.Value = Convert.ToString(value) ?? string.Empty;
                break;
        }
    }

    private static XLAlignmentHorizontalValues ToClosedXmlAlignment(ExcelExportAlignment alignment) =>
        alignment switch
        {
            ExcelExportAlignment.Center => XLAlignmentHorizontalValues.Center,
            ExcelExportAlignment.Right => XLAlignmentHorizontalValues.Right,
            _ => XLAlignmentHorizontalValues.Left
        };

    private static string SanitizeWorksheetName(string name)
    {
        var invalidCharacters = new[] { ':', '\\', '/', '?', '*', '[', ']' };
        var sanitized = invalidCharacters.Aggregate(name, (current, character) => current.Replace(character, '-'));
        return string.IsNullOrWhiteSpace(sanitized) ? "Rapor" : sanitized[..Math.Min(31, sanitized.Length)];
    }

    private static string SanitizeTableName(string name)
    {
        var sanitized = new string(name.Where(char.IsLetterOrDigit).ToArray());
        if (string.IsNullOrWhiteSpace(sanitized))
        {
            return "RaporTablosu";
        }

        return char.IsDigit(sanitized[0]) ? $"Rapor{sanitized}" : sanitized;
    }
}
