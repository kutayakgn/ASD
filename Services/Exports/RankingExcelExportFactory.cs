using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class RankingExcelExportFactory
{
    public static ExcelExportDocument Create(RankingTableViewModel report)
    {
        var metricHeader = report.RankingType switch
        {
            RankingTypes.Arithmetic => "Aritmetik Ortalama",
            RankingTypes.Confidence => "Güven Puanı",
            _ => "Trim Ortalama"
        };
        var displayNameHeader = report.CategoryHasRoleAndPhoto ? "Adı Soyadı" : "Tiyatro Adı";
        var categoryName = report.Categories.First(category =>
            category.CategoryCode == report.CategoryCode).CategoryName;

        return new ExcelExportDocument
        {
            WorksheetName = "Sıralamalar",
            TableName = "Siralamalar",
            Title = $"{categoryName} - {metricHeader}",
            Columns =
            [
                Column("Sıra", 10, ExcelExportAlignment.Center),
                Column("Kategori", 38),
                Column(displayNameHeader, 34),
                Column("Oyun Adı", 34),
                Column("İzlenme Sayısı", 18, ExcelExportAlignment.Center),
                Column(metricHeader, 20, ExcelExportAlignment.Center)
            ],
            Rows = report.Rows.Select(row => (IReadOnlyList<ExcelExportCell>)
            [
                Cell(row.Position),
                Cell(row.CategoryName),
                Cell(row.DisplayName),
                Cell(row.PlayName),
                Cell(row.ViewCount),
                Cell(row.MetricValue)
            ]).ToArray(),
            FooterLines = [$"Toplam kayıt sayısı: {report.Rows.Count}"]
        };
    }

    private static ExcelExportColumn Column(
        string header,
        double width,
        ExcelExportAlignment alignment = ExcelExportAlignment.Left) =>
        new() { Header = header, Width = width, Alignment = alignment };

    private static ExcelExportCell Cell(object? value) => new() { Value = value };
}
