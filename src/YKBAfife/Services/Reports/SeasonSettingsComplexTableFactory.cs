using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class SeasonSettingsComplexTableFactory
{
    private const string TabKey = "season-settings";

    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new() { Title = "Sezon Adı", Key = SeasonSettingsSortColumns.Season, ColWidth = 16 },
        new() { Title = "Sezon Başlangıç", Key = SeasonSettingsSortColumns.SeasonStartDate, ColWidth = 14 },
        new() { Title = "Künye Kayıt Başlangıç", Key = SeasonSettingsSortColumns.KunyeRegistrationStartDate, ColWidth = 14 },
        new() { Title = "Künye Kayıt Bitiş", Key = SeasonSettingsSortColumns.KunyeRegistrationEndDate, ColWidth = 14 },
        new() { Title = "Oylama Başlangıç", Key = SeasonSettingsSortColumns.VotingStartDate, ColWidth = 14 },
        new() { Title = "Oylama Bitiş", Key = SeasonSettingsSortColumns.VotingEndDate, ColWidth = 14 },
        new() { Title = "Sezon Bitiş", Key = SeasonSettingsSortColumns.SeasonEndDate, ColWidth = 14 }
    ];

    public static ComplexTableViewModel Create(SeasonSettingsTableViewModel report) => new()
    {
        Id = "season-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        DataActionName = "SeasonSettingsTable",
        CurrentTabKey = TabKey,
        ShowSearch = false,
        MinimumTableWidth = 1280,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "Sezon Ayarları",
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = SeasonSettingsTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Tanımlı sezon bulunamadı.",
                Columns = Columns,
                HeaderActions =
                [
                    new ComplexTableHeaderActionViewModel
                    {
                        Text = "Sezon Ekle",
                        Icon = "/icons/plus.svg",
                        Link = "/diger-ayarlar/sezon-ekle"
                    }
                ],
                Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"season-setting-{row.Id:N}",
                    Link = $"/diger-ayarlar/sezonlar/{row.Id}",
                    Cells =
                    [
                        Cell(row.SeasonName),
                        Cell(row.SeasonStartDate),
                        Cell(row.KunyeRegistrationStartDate),
                        Cell(row.KunyeRegistrationEndDate),
                        Cell(row.VotingStartDate),
                        Cell(row.VotingEndDate),
                        Cell(row.SeasonEndDate)
                    ]
                }).ToArray()
            }
        ]
    };

    private static ComplexTableCellViewModel Cell(string value) => new() { Content = value };
    private static ComplexTableCellViewModel Cell(DateOnly value) => new() { Content = value.ToString("dd.MM.yyyy") };
}
