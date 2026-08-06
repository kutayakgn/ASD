using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class PlayVoteExcelExportFactory
{
    public static ExcelExportDocument Create(string playName, IReadOnlyList<PlayVoteExportRowViewModel> rows) => new()
    {
        WorksheetName = "Oyun Oyları",
        Title = $"{playName} - Tüm Oylar",
        TableName = "OyunJuriOylari",
        MetadataLines = ExcelExportMetadata.Create("Jüri Adı", "asc", [$"Oyun = {playName}" ]),
        Columns =
        [
            new() { Header = "Jüri Adı", Width = 28 },
            new() { Header = "Kategori Adı", Width = 42 },
            new() { Header = "Rol Adı", Width = 24 },
            new() { Header = "Jüri Puanı", Width = 14, Alignment = ExcelExportAlignment.Center },
            new() { Header = "Oy Tarihi", Width = 22 },
            new() { Header = "IsActive", Width = 12, Alignment = ExcelExportAlignment.Center }
        ],
        Rows = rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [
            new() { Value = row.JuryName },
            new() { Value = row.CategoryName },
            new() { Value = string.IsNullOrWhiteSpace(row.RoleName) ? "-" : row.RoleName },
            new() { Value = row.Score },
            new() { Value = row.VoteDate },
            new() { Value = row.IsActive }
        ]).ToArray(),
        FooterLines = [$"Toplam oy sayısı: {rows.Count}"]
    };

}

public static class CandidateExcelExportFactory
{
    public static ExcelExportDocument Create(string playName, IReadOnlyList<CandidateTableRowViewModel> rows, CandidateTableQuery query) => new()
    {
        WorksheetName = "Adaylar",
        Title = $"{playName} - Adaylar ve Kategorileri",
        TableName = "OyunAdaylari",
        MetadataLines = ExcelExportMetadata.Create(CandidateSortLabel(query.SortBy), query.SortDirection,
            [$"Oyun = {playName}", query.CategoryCode.HasValue ? $"Kategori = {rows.FirstOrDefault()?.CategoryName ?? query.CategoryCode.ToString()}" : "Kategori = Tümü"]),
        Columns =
        [
            new() { Header = "Ödül Kategorisi", Width = 42 },
            new() { Header = "Aday Adı", Width = 28 },
            new() { Header = "Rol Adı", Width = 24 },
            new() { Header = "Rol Değişimi", Width = 16 },
            new() { Header = "Eklenme Tarihi", Width = 22 },
            new() { Header = "Statü", Width = 14 }
        ],
        Rows = rows.Select(row => (IReadOnlyList<ExcelExportCell>)
        [
            new() { Value = row.CategoryName },
            new() { Value = row.Candidate },
            new() { Value = string.IsNullOrWhiteSpace(row.Role) ? "-" : row.Role },
            new() { Value = row.RoleCandidateCount <= 1 ? "-" : row.IsCurrent ? "Yeni Aday" : "Eski Aday" },
            new() { Value = row.CreatedAt },
            new() { Value = row.IsActive ? "Aktif" : "Aktif Değil" }
        ]).ToArray(),
        FooterLines = [$"Toplam aday sayısı: {rows.Count}"]
    };

    private static string CandidateSortLabel(string sortBy) => sortBy switch
    {
        CandidateSortColumns.Candidate => "Adı Soyadı",
        CandidateSortColumns.Role => "Rol Adı",
        CandidateSortColumns.Replacement => "Rol Değişimi",
        CandidateSortColumns.CreatedAt => "Eklenme Tarihi",
        CandidateSortColumns.Status => "Statü",
        _ => "Ödül Kategorisi"
    };
}