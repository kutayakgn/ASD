using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class AdminComplexTableFactory
{
    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new() { Title = "Kullanıcı Adı", Key = AdminSortColumns.Username, ColWidth = 44 },
        new() { Title = "Adı Soyadı", Key = AdminSortColumns.FullName, ColWidth = 44 },
        new() { Title = "Statü", Key = "status", ColWidth = 12, IsSortable = false, CssClass = "admin-status-column" }
    ];

    public static ComplexTableViewModel Create(AdminTableViewModel report, Guid currentUserId)
    {
        var rows = report.Rows.Select(row =>
        {
            var detailsUrl = $"/admin-yonetimi/{row.UserId:D}";
            return new ComplexTableRowViewModel
            {
                Id = $"admin-{row.UserId:N}",
                NavigationUrl = detailsUrl,
                NavigationAccessibleLabel = $"{row.FullName} detay\u0131na git",
                Cells =
                [
                    new()
                    {
                        Content = row.Username,
                        Link = detailsUrl,
                        AccessibleLabel = $"{row.Username} admin detay\u0131na git"
                    },
                    new()
                    {
                        Content = row.FullName,
                        Link = detailsUrl,
                        AccessibleLabel = $"{row.FullName} admin detay\u0131na git"
                    },
                    new()
                    {
                        ToggleUrl = $"/admin-yonetimi/{row.UserId:D}/status",
                        ToggleChecked = row.IsActive,
                        ToggleDisabled = row.UserId == currentUserId,
                        AccessibleLabel = row.UserId == currentUserId
                            ? $"{row.FullName} stat\u00fcs\u00fc de\u011fi\u015ftirilemez"
                            : $"{row.FullName} stat\u00fcs\u00fcn\u00fc de\u011fi\u015ftir",
                        CssClass = "admin-status-cell"
                    }
                ]
            };
        }).ToArray();

        return new ComplexTableViewModel
        {
            Id = "admin-management-table",
            ControllerName = "AdminManagement",
            ActionName = "Index",
            DataActionName = "Table",
            CurrentTabKey = "admins",
            SearchPlaceholder = "Ara",
            MinimumTableWidth = 760,
            IsNavigationColActive = true,
            Tabs =
            [
                new()
                {
                    Key = "admins",
                    Title = "Admin Y\u00f6netimi",
                    Search = report.Search,
                    SortBy = report.SortBy,
                    SortDirection = report.SortDirection,
                    CurrentPage = report.CurrentPage,
                    PageSize = AdminTableViewModel.PageSize,
                    TotalCount = report.TotalCount,
                    EmptyMessage = "Arama kriterlerine uygun admin bulunamad\u0131.",
                    Columns = Columns,
                    Rows = rows,
                    HeaderActions = [new() { Icon= "/icons/plus.svg", Text = "Admin Ekle", Link = "/admin-yonetimi/ekle" }]
                }
            ],
            SummaryContent =
            [
                new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
                new() { Text = " kay\u0131t bulundu." }
            ]
        };
    }
}
