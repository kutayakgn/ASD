using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class AdditionalVotingComplexTableFactory
{
    private const string TabKey = "additional-votings";
    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new() { Title = "Ek Oylama Başlangıç Süresi", Key = AdditionalVotingSortColumns.StartDate, ColWidth = 17 },
        new() { Title = "Ek Oylama Bitiş Süresi", Key = AdditionalVotingSortColumns.EndDate, ColWidth = 17 },
        new() { Title = "Oy Verebilecek Jüriler", Key = AdditionalVotingSortColumns.Juries, ColWidth = 18 },
        new() { Title = "Oy Verilebilecek Oyunlar", Key = AdditionalVotingSortColumns.Plays, ColWidth = 18 },
        new() { Title = "İlk Defa Oy Kullananlar", Key = AdditionalVotingSortColumns.FirstVotes, ColWidth = 15 },
        new() { Title = "Oyunu Güncelleyenler", Key = AdditionalVotingSortColumns.VoteUpdates, ColWidth = 15 }
    ];

    public static ComplexTableViewModel Create(AdditionalVotingTableViewModel report) => new()
    {
        Id = "additional-voting-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        DataActionName = "AdditionalVotingTable",
        CurrentTabKey = TabKey,
        ShowSearch = false,
        IsEditableRows = true,

        MinimumTableWidth = 1120,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "",
                SortBy = report.SortBy,
                SortDirection = report.SortDirection,
                CurrentPage = report.CurrentPage,
                PageSize = AdditionalVotingTableViewModel.PageSize,
                TotalCount = report.TotalCount,
                EmptyMessage = "Tanımlı ek oylama hakkı bulunamadı.",
                Columns = Columns,
                HeaderActions =
                [
                    new ComplexTableHeaderActionViewModel
                    {
                        Text = "Ek Oylama Hakkı Oluştur",
                        Icon = "/icons/plus.svg",
                        Link = "/diger-ayarlar/ek-oylama-ekle"
                    }
                ],
                Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"additional-voting-{row.Id:N}",
                    Link = $"/diger-ayarlar/ek-oylamalar/{row.Id}",
                    EditUrl = $"/diger-ayarlar/ek-oylamalar/{row.Id}/duzenle",
                    EditAccessibleLabel = $"{row.StartDate:dd.MM.yyyy} tarihli ek oylama hakkını düzenle",
                    Cells =
                    [
                        Cell($"{row.StartDate:dd.MM.yyyy} 00:00:01"),
                        Cell($"{row.EndDate:dd.MM.yyyy} 23:59:59"),
                        Cell(row.AppliesToAllJuries ? "Tüm Jüriler" : $"{row.JuryCount} jüri"),
                        Cell(row.AppliesToAllPlays ? "Tüm Oyunlar" : $"{row.PlayCount} oyun"),
                        Cell(row.FirstVoteUserCount.ToString()),
                        Cell(row.VoteUpdateUserCount.ToString())
                    ]
                }).ToArray()
            }
        ]
    };

    private static ComplexTableCellViewModel Cell(string value) => new() { Content = value };
}
