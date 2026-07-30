using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class RankingExcelExportFactory
{
    public static ExcelExportDocument Create(RankingTableViewModel report, bool currentPageOnly)
    {
        var metricHeader = report.RankingType switch
        {
            RankingTypes.Arithmetic => "Aritmetik Ortalama",
            RankingTypes.Confidence => "Güven Puanı",
            _ => "Trim Ortalama"
        };
        var displayNameHeader = report.CategoryHasRoleAndPhoto ? "Adı Soyadı" : "Tiyatro Adı";
        var categoryName = report.Categories.First(category => category.CategoryCode == report.CategoryCode).CategoryName;
        var includeVariance = report.RankingType != RankingTypes.Trimmed;
        var columns = new List<ExcelExportColumn>
        {
            Column("Sıra", 10, ExcelExportAlignment.Center), Column("Kategori", 38),
            Column(displayNameHeader, 34), Column("Oyun Adı", 34),
            Column("Toplam Puan", 16, ExcelExportAlignment.Center),
            Column("Oy Sayısı", 18, ExcelExportAlignment.Center)
        };
        if (includeVariance) columns.Add(Column("Varyans", 16, ExcelExportAlignment.Center));
        columns.Add(Column(metricHeader, 20, ExcelExportAlignment.Center));

        var rows = report.Rows.Select(row =>
        {
            var cells = new List<ExcelExportCell>
            {
                Cell(row.Position), Cell(row.CategoryName), Cell(row.DisplayName), Cell(row.PlayName),
                Cell(row.TotalScore), Cell(row.ViewCount)
            };
            if (includeVariance) cells.Add(Cell(row.Variance));
            cells.Add(Cell(report.RankingType == RankingTypes.Confidence && row.ConfidenceValue.HasValue
                ? $"{row.ConfidenceValue}/4" : row.MetricValue));
            return (IReadOnlyList<ExcelExportCell>)cells;
        }).ToArray();

        return new ExcelExportDocument
        {
            WorksheetName = "Sıralamalar", TableName = "Siralamalar",
            MetadataLines = ExcelExportMetadata.Create(
                metricHeader,
                "desc",
                [$"Kategori = {categoryName}", $"Görünüm = {report.PageSize} satır"],
                currentPageOnly ? report.CurrentPage : null),
            Title = $"{categoryName} - {metricHeader}", Columns = columns, Rows = rows,
            FooterLines = [$"Toplam kayıt sayısı: {rows.Length}"]
        };
    }

    private static ExcelExportColumn Column(string header, double width,
        ExcelExportAlignment alignment = ExcelExportAlignment.Left) =>
        new() { Header = header, Width = width, Alignment = alignment };
    private static ExcelExportCell Cell(object? value) => new() { Value = value };
}
