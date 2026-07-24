using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class CandidateComplexTableFactory
{
    public static ComplexTableViewModel Create(CandidateTableViewModel report) => new()
    {
        Id = "play-candidates-table",
        ControllerName = "Management",
        DataActionName = "CandidateTable",
        CurrentTabKey = "candidates",
        ShowSearch = false,
        MinimumTableWidth = 1100,
        IsDeleteColActive = true,
        IsNavigationColActive = true,
        ExportControllerName = "Management",
        ExportActionName = "ExportCandidates",
        ExportButtonText = "Adaylar ve Kategorileri Yazdır",
        IsExportEnabled = report.TotalCount > 0,
        AdditionalRouteValues = new Dictionary<string, string?>
        {
            ["playId"] = report.PlayId.ToString("D"),
            ["categoryCode"] = report.CategoryCode?.ToString(CultureInfo.InvariantCulture)
        },
        SelectFilter = new ComplexTableSelectFilterViewModel
        {
            Name = "categoryCode",
            Label = "Ödül Kategorisi",
            Value = report.CategoryCode?.ToString(CultureInfo.InvariantCulture) ?? string.Empty,
            Options =
            [
                new() { Value = string.Empty, Text = "Tüm Adaylar" },
                .. report.Categories.Select(category => new ComplexTableSelectOptionViewModel
                {
                    Value = category.CategoryCode.ToString(CultureInfo.InvariantCulture),
                    Text = category.CategoryName
                })
            ]
        },
        Tabs =
        [
            new()
            {
                Key = "candidates",
                Title = "Adaylar",
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = CandidateTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Seçilen kategori için aday bulunamadı.",
                Columns =
                [
                    new() { Title = "Ödül Kategorisi", Key = CandidateSortColumns.Category, ColWidth = 23 },
                    new() { Title = "Adı Soyadı", Key = CandidateSortColumns.Candidate, ColWidth = 19 },
                    new() { Title = "Role Adı", Key = CandidateSortColumns.Role, ColWidth = 15 },
                    new() { Title = "Rol Değişimi", Key = CandidateSortColumns.Replacement, ColWidth = 15 },
                    new() { Title = "Eklenme Tarihi", Key = CandidateSortColumns.CreatedAt, ColWidth = 16 },
                    new() { Title = "Statü", Key = CandidateSortColumns.Status, ColWidth = 12, CssClass = "candidate-status-column" }
                ],
                Rows = report.Rows.Select(CreateRow).ToArray()
            }
        ],
        SummaryContent =
        [
            new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
            new() { Text = " aday bulundu." }
        ]
    };

    private static ComplexTableRowViewModel CreateRow(CandidateTableRowViewModel row)
    {
        var detailsUrl = $"/adaylar/{row.Id:D}";
        var replacement = row.RoleCandidateCount <= 1 ? "-" : row.IsCurrent ? "Yeni Aday" : "Eski Aday";
        return new ComplexTableRowViewModel
        {
            Id = $"candidate-{row.Id:N}",
            Link = detailsUrl,
            NavigationUrl = detailsUrl,
            NavigationAccessibleLabel = $"{row.Candidate} aday detayına git",
            DeleteUrl = row.CategoryCode == 1001 ? string.Empty : $"/adaylar/{row.Id:D}/sil",
            DeleteConfirmMessage = "İlgili aday kaydı silinsin mi?",
            DeleteAccessibleLabel = $"{row.Candidate} aday kaydını sil",
            Cells =
            [
                LinkCell(row.CategoryName, detailsUrl),
                LinkCell(row.Candidate, detailsUrl),
                LinkCell(string.IsNullOrWhiteSpace(row.Role) ? "-" : row.Role, detailsUrl),
                LinkCell(replacement, detailsUrl),
                LinkCell(row.CreatedAt?.ToString("dd.MM.yyyy HH:mm", CultureInfo.CurrentCulture) ?? "-", detailsUrl),
                new()
                {
                    ToggleUrl = $"/adaylar/{row.Id:D}/status",
                    ToggleChecked = row.IsActive,
                    AccessibleLabel = $"{row.Candidate} statüsünü değiştir",
                    CssClass = "candidate-status-cell"
                }
            ]
        };
    }

    private static ComplexTableCellViewModel LinkCell(string content, string link) => new()
    {
        Content = content,
        Link = link
    };
}