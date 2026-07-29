using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class RankingVoteExcelExportFactory
{
    public static ExcelExportDocument Create(RankingVoteTableViewModel report) => new()
    {
        WorksheetName = "Jüri Oyları",
        MetadataLines = ExcelExportMetadata.Create(
            report.SortBy == RankingVoteSortColumns.Score ? "Puan" : "Jüri Adı Soyadı",
            report.SortDirection,
            [$"Oyun = {report.PlayName}" ]),
        TableName = "JuriOylari",
        Title = report.PlayName,
        Columns =
        [
            new() { Header = "Jüri Adı Soyadı", Width = 36 },
            new() { Header = "Puan", Width = 14, Alignment = ExcelExportAlignment.Center }
        ],
        Rows = report.Rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [new() { Value = row.JuryFullName }, new() { Value = row.Score }]).ToArray(),
        FooterLines = [$"Toplam kayıt sayısı: {report.Rows.Count}"]
    };
}
