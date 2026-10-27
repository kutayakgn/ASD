using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class GroupSettingsComplexTableFactory
{
    public static ComplexTableViewModel Create(IReadOnlyList<GroupSettingsRowViewModel> rows) => new()
    {
        Id = "group-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        DataActionName = "GroupSettingsTable",
        CurrentTabKey = "group-settings",
        ShowSearch = false,
        IsEditableRows = true,
        IsDeleteColActive = true,
        MinimumTableWidth = 540,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = "group-settings",
                Title = "",
                PageSize = Math.Max(1, rows.Count),
                TotalCount = rows.Count,
                EmptyMessage = "Tanımlı jüri grubu bulunamadı.",
                Columns =
                [
                    new() { Title = "Code", Key = "code", ColWidth = 20, IsSortable = false },
                    new() { Title = "GroupName", Key = "groupName", ColWidth = 80, IsSortable = false }
                ],
                HeaderActions =
                [
                    new() { Text = "Grup Ekle", Icon = "/icons/plus.svg", Link = "/diger-ayarlar/gruplar/ekle" }
                ],
                Rows = rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"group-{row.Id:N}",
                    EditUrl = $"/diger-ayarlar/gruplar/{row.Id}/duzenle",
                    EditAccessibleLabel = $"{row.GroupName} grubunu düzenle",
                    DeleteUrl = $"/diger-ayarlar/gruplar/{row.Id}/sil",
                    DeleteAccessibleLabel = $"{row.GroupName} grubunu sil",
                    DeleteConfirmMessage = $"{row.GroupName} grubunu silmek istediğinize emin misiniz?",
                    Cells =
                    [
                        new() { Content = row.Code.ToString(CultureInfo.InvariantCulture) },
                        new() { Content = row.GroupName }
                    ]
                }).ToArray()
            }
        ]
    };
}
