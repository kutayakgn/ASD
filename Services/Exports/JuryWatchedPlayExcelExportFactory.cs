using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class JuryWatchedPlayExcelExportFactory
{
    public static ExcelExportDocument Create(JuryWatchedPlayExportViewModel report, JuryWatchedPlayTableQuery query) => new()
    {
        WorksheetName = "İzlenmeler",
        TableName = "JuriIzlenmeleri",
        Title = $"{report.JuryName} - İzlenmeler",
        MetadataLines = ExcelExportMetadata.Create("Oyun Adı", query.SortDirection,
            [$"Jüri = {report.JuryName}", ExcelExportMetadata.SearchFilter(query.Search)]),
        Columns =
        [
            new ExcelExportColumn { Header = "Oyun Adı", Width = 42 },
            new ExcelExportColumn { Header = "İzlenme Tarihi", Width = 22 }
        ],
        Rows = report.Rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [
            new ExcelExportCell { Value = row.PlayName },
            new ExcelExportCell { Value = row.WatchedAt?.ToString("dd.MM.yyyy") ?? "-" }
        ]).ToArray(),
        FooterLines = [$"Toplam kayıt sayısı: {report.Rows.Count}"]
    };
}
