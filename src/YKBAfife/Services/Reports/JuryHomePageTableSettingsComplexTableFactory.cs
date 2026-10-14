using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class JuryHomePageTableSettingsComplexTableFactory
{
    private const string TabKey = "jury-home-page-table-settings";

    public static ComplexTableViewModel Create(
        IReadOnlyList<JuryHomePageTableSettingsRowViewModel> rows) => new()
    {
        Id = "jury-home-page-table-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        CurrentTabKey = TabKey,
        ShowHeading = false,
        ShowSearch = false,
        MinimumTableWidth = 480,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "",
                PageSize = Math.Max(1, rows.Count),
                TotalCount = rows.Count,
                EmptyMessage = "Jüri paneli ana ekran tablo ayarı bulunamadı.",
                Columns =
                [
                    new() { Title = "Tablo Adı", Key = "tableName", ColWidth = 88, IsSortable = false },
                    new() { Title = "Statü", Key = "status", ColWidth = 12, IsSortable = false }
                ],
                Rows = rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"jury-home-page-{row.ConfigName}",
                    Cells =
                    [
                        new() { Content = row.Title },
                        new()
                        {
                            ToggleUrl = $"/diger-ayarlar/juri-ana-ekran-tablolari/{Uri.EscapeDataString(row.ConfigName)}/status",
                            ToggleChecked = row.IsEnabled,
                            ToggleDisabled = !row.IsAvailable,
                            AccessibleLabel = row.IsAvailable
                                ? $"{row.Title} tablosunun görünürlüğünü değiştir"
                                : $"{row.Title} tablo ayarı bulunamadı"
                        }
                    ]
                }).ToArray()
            }
        ]
    };
}
