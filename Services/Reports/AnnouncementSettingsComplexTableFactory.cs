using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class AnnouncementSettingsComplexTableFactory
{
    private const string TabKey = "announcement-settings";

    public static ComplexTableViewModel Create(IReadOnlyList<AnnouncementSettingsRowViewModel> rows) => new()
    {
        Id = "announcement-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        CurrentTabKey = TabKey,
        ShowHeading = true,
        ShowSearch = false,
        MinimumTableWidth = 680,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "Duyurular",
                PageSize = Math.Max(1, rows.Count),
                TotalCount = rows.Count,
                EmptyMessage = "Yayınlanmış duyuru bulunamadı.",
                Columns =
                [
                    new() { Title = "Duyuru Konum ID", Key = "announcementLocationId", ColWidth = 25, IsSortable = false },
                    new() { Title = "Metin", Key = "text", ColWidth = 75, IsSortable = false }
                ],
                Rows = rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"announcement-{row.Id:N}",
                    Link = $"/diger-ayarlar/duyurular/{row.Id}",
                    Cells =
                    [
                        new ComplexTableCellViewModel { Content = row.AnnouncementLocationId.ToString() },
                        new ComplexTableCellViewModel { Content = row.Text }
                    ]
                }).ToArray()
            }
        ]
    };
}
