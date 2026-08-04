using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class JuryComplexTableFactory
{
    private static readonly IReadOnlyList<ComplexTableColumnViewModel> CurrentColumns =
    [
        new() { Title = "Kullanıcı Adı", Key = JurySortColumns.Username, ColWidth = 16 },
        new() { Title = "E-posta", Key = JurySortColumns.Email, ColWidth = 22 },
        new() { Title = "Adı Soyadı", Key = JurySortColumns.FullName, ColWidth = 22 },
        new() { Title = "Telefon", Key = JurySortColumns.Phone, ColWidth = 15 },
        new() { Title = "İzleme", Key = JurySortColumns.WatchCount, ColWidth = 10 },
        new() { Title = "Kayıt Tarihi", Key = JurySortColumns.CreatedAt, ColWidth = 15 }
    ];

    private static readonly IReadOnlyList<ComplexTableColumnViewModel> HistoricalColumns =
    [
        new() { Title = "Kullanıcı Adı", Key = JurySortColumns.Username, ColWidth = 20 },
        new() { Title = "E-posta", Key = JurySortColumns.Email, ColWidth = 30 },
        new() { Title = "Adı Soyadı", Key = JurySortColumns.FullName, ColWidth = 30 },
        new() { Title = "Telefon", Key = JurySortColumns.Phone, ColWidth = 20 }
    ];

    public static ComplexTableViewModel Create(JuryTableViewModel report)
    {
        var isCurrent = report.CurrentTab == JuryTabs.Current;
        var rows = report.Rows.Select(row => new ComplexTableRowViewModel
        {
            Id = $"jury-{row.UserId:N}",
            Link = $"/juriler/{row.UserId:D}",
            Cells = isCurrent
                ?
                [
                    Cell(row.Username),
                    Cell(row.Email),
                    Cell(row.FullName),
                    Cell(row.Phone),
                    Cell(row.WatchCount.ToString(CultureInfo.CurrentCulture)),
                    Cell(row.CreatedAt?.ToString("dd.MM.yyyy", CultureInfo.CurrentCulture) ?? "-")
                ]
                :
                [
                    Cell(row.Username),
                    Cell(row.Email),
                    Cell(row.FullName),
                    Cell(row.Phone)
                ]
        }).ToArray();

        ComplexTableTabViewModel CreateTab(string key, string title) => new()
        {
            Key = key,
            Title = title,
            Search = report.Search,
            SortBy = report.SortBy,
            SortDirection = report.SortDirection,
            CurrentPage = report.CurrentPage,
            PageSize = JuryTableViewModel.PageSize,
            TotalCount = key == report.CurrentTab ? report.TotalCount : 0,
            EmptyMessage = "Arama ölçütlerine uygun jüri bulunamadı.",
            Columns = key == JuryTabs.Current ? CurrentColumns : HistoricalColumns,
            Rows = key == report.CurrentTab ? rows : [],
            HeaderActions = key == JuryTabs.Current
                ? [new ComplexTableHeaderActionViewModel { Icon = "/icons/plus.svg", Text = "Jüri Ekle", Link = "/juri-ekle" }]
                : []
        };

        return new ComplexTableViewModel
        {
            Id = "jury-table",
            ControllerName = "Management",
            ActionName = "Juries",
            DataActionName = "JuryTable",
            CurrentTabKey = report.CurrentTab,
            SearchPlaceholder = "Kullanıcı adı, e-posta, adı soyadı veya telefon ara",
            MinimumTableWidth = 1050,
            Tabs =
            [
                CreateTab(JuryTabs.Current, "Güncel Jüriler"),
                CreateTab(JuryTabs.Historical, "Geçmiş Jüriler")
            ],
            SummaryContent =
            [
                new()
                {
                    Text = report.TotalCount.ToString(CultureInfo.CurrentCulture),
                    IsEmphasized = true
                },
                new() { Text = " kayıt bulundu." }
            ]
        };
    }

    private static ComplexTableCellViewModel Cell(string content) => new() { Content = content };
}
