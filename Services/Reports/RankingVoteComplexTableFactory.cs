using System.Globalization;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class RankingVoteComplexTableFactory
{
    public static ComplexTableViewModel Create(RankingVoteTableViewModel report) => new()
    {
        Id = "ranking-votes-table",
        ControllerName = "Management",
        DataActionName = "RankingVotesTable",
        CurrentTabKey = "votes",
        ShowHeading = false,
        ShowSearch = false,
        MinimumTableWidth = 480,
        ExportControllerName = "Management",
        ExportActionName = "ExportRankingVotes",
        ExportButtonText = "Excele Aktar",
        IsExportEnabled = report.TotalCount > 0,
        AdditionalRouteValues = new Dictionary<string, string?>
        {
            ["playAwardCategoryId"] = report.PlayAwardCategoryId.ToString()
        },
        Tabs =
        [
            new()
            {
                Key = "votes", Title = report.PlayName, SortBy = report.SortBy,
                SortDirection = report.SortDirection, CurrentPage = report.CurrentPage,
                PageSize = RankingVoteTableViewModel.PageSize, TotalCount = report.TotalCount,
                EmptyMessage = "Bu sıralama kaydı için aktif oy bulunamadı.",
                Columns =
                [
                    new() { Title = "Jüri Adı Soyadı", Key = RankingVoteSortColumns.JuryName, ColWidth = 74 },
                    new() { Title = "Puan", Key = RankingVoteSortColumns.Score, ColWidth = 26 }
                ],
                Rows = report.Rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"vote-{row.VoteId:N}",
                    Cells =
                    [
                        new() { Content = row.JuryFullName },
                        new() { Content = row.Score.ToString("0.00", CultureInfo.CurrentCulture) }
                    ]
                }).ToArray()
            }
        ],
        SummaryContent =
        [
            new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
            new() { Text = " kayıt bulundu." }
        ]
    };
}
