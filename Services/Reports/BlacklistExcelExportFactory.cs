using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class BlacklistExcelExportFactory
{
    public static ExcelExportDocument Create(IReadOnlyList<BlacklistRowViewModel> rows) => new()
    {
        WorksheetName = "Blacklists",
        Title = "Blacklists",
        TableName = "BlacklistKayitlari",
        Columns =
        [
            new() { Header = "Jüri", Width = 28 },
            new() { Header = "Oyun", Width = 36 },
            new() { Header = "Eklenme Tarihi", Width = 20 },
            new() { Header = "Ekleyen", Width = 28 }
        ],
        Rows = rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [
            new() { Value = row.JuryName },
            new() { Value = row.PlayName },
            new() { Value = row.CreatedOn },
            new() { Value = row.CreatedByName }
        ]).ToArray(),
        FooterLines = [$"Toplam kayıt sayısı: {rows.Count}"]
    };
}
