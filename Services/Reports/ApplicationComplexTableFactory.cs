using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class ApplicationComplexTableFactory
{
    private const string TabKey = "applications";

    public static ComplexTableViewModel Create(ApplicationTableViewModel report) => new()
    {
        Id = "applications-table",
        ControllerName = "Management",
        ActionName = "Applications",
        DataActionName = "ApplicationsTable",
        CurrentTabKey = TabKey,
        SearchPlaceholder = "Ara",
        MinimumTableWidth = 1180,
        IsDeleteColActive = true,
        IsNavigationColActive = true,
        SelectFilters =
        [
            new()
            {
                Name = "PageSize",
                AccessibleLabel = "Sayfadaki satır sayısı",
                ShowLabel = false,
                Value = report.PageSize.ToString(CultureInfo.InvariantCulture),
                Options =
                [
                    Option("5", "5'li Görünüm"), Option("10", "10'lu Görünüm"),
                    Option("15", "15'li Görünüm"), Option("20", "20'li Görünüm")
                ]
            }
        ],
        Tabs =
        [
            new()
            {
                Key = TabKey,
                Title = "Başvurular",
                Search = report.Search,
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = report.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Başvuru bulunamadı.",
                Columns =
                [
                    new() { Title = "Başvuru No", Key = ApplicationSortColumns.ApplicationNumber, ColWidth = 12 },
                    new() { Title = "Oyun", Key = ApplicationSortColumns.Play, ColWidth = 26 },
                    new() { Title = "Başvuran E-posta", Key = ApplicationSortColumns.Email, ColWidth = 25 },
                    new() { Title = "Başvuran Telefon", Key = ApplicationSortColumns.Phone, ColWidth = 11.1m },
                    new() { Title = "Başvuru Tarihi", Key = ApplicationSortColumns.CreatedDate, ColWidth = 14 },
                    new() { Title = "Statü", Key = ApplicationSortColumns.Status, ColWidth = 11.9m, CssClass = "applications-status-column" }
                ],
                Rows = report.Rows.Select(CreateRow).ToArray()
            }
        ],
        SummaryContent =
        [
            new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
            new() { Text = " kayıt bulundu." }
        ]
    };

    private static ComplexTableRowViewModel CreateRow(ApplicationRowViewModel row)
    {
        var detailsUrl = $"/basvurular/{row.Id:D}";
        return new ComplexTableRowViewModel
        {
            Id = $"application-{row.Id:N}",
            Link = detailsUrl,
            NavigationUrl = detailsUrl,
            NavigationAccessibleLabel = $"{row.ApplicationNumber} numaralı başvurunun detayını aç",
            DeleteUrl = $"/basvurular/{row.Id:D}/sil",
            DeleteConfirmMessage = "İlgili başvuru silinsin mi?",
            DeleteAccessibleLabel = $"{row.ApplicationNumber} numaralı başvuruyu sil",
            Cells =
            [
                Cell(row.ApplicationNumber), Cell(row.PlayName), Cell(row.Email), Cell(row.Phone),
                Cell(row.CreatedDate?.ToString("dd.MM.yyyy HH:mm:ss", CultureInfo.CurrentCulture) ?? "-"),
                new()
                {
                    ToggleUrl = $"/basvurular/{row.Id:D}/status",
                    ToggleChecked = row.IsActive,
                    AccessibleLabel = $"{row.ApplicationNumber} numaralı başvurunun statüsünü değiştir"
                }
            ]
        };
    }

    private static ComplexTableCellViewModel Cell(string content) => new() { Content = content };
    private static ComplexTableSelectOptionViewModel Option(string value, string text) => new() { Value = value, Text = text };
}
