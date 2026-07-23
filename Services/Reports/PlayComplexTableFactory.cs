using System.Globalization;
using YKBAfife.Helpers;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class PlayComplexTableFactory
{
    private static readonly IReadOnlyList<ComplexTableColumnViewModel> Columns =
    [
        new() { Title = "Oyun Adı", Key = PlaySortColumns.PlayName, ColWidth = 30 },
        new() { Title = "Tiyatro Adı", Key = PlaySortColumns.TheaterName, ColWidth = 18 },
        new() { Title = "Eklenme Yöntemi", Key = PlaySortColumns.RecordType, ColWidth = 14 },
        new() { Title = "Eklenme Tarihi", Key = PlaySortColumns.CreatedAt, ColWidth = 18 },
        new() { Title = "Jüri Oylama Listesi", Key = PlaySortColumns.JuryVotingStatus, ColWidth = 10 },
        new() { Title = "Künye Giriş Sistemi", Key = PlaySortColumns.KunyeGirisStatus, ColWidth = 10 }
    ];

    public static ComplexTableViewModel Create(PlayTableViewModel report)
    {
        var activeFilterCount = new[] { report.JuryVotingStatus, report.KunyeGirisStatus, report.RecordType }
            .Count(value => value.HasValue);
        var rows = report.Rows.Select(row =>
        {
            var slug = SlugHelper.Resolve(row.Slug, row.PlayName);
            var detailsUrl = $"/oyunlar/{Uri.EscapeDataString(slug)}";
            return new ComplexTableRowViewModel
            {
                Id = $"play-{row.PlayId:N}",
                NavigationUrl = detailsUrl,
                NavigationAccessibleLabel = $"{row.PlayName} oyun detayına git",
                Cells =
                [
                    new() { Content = row.PlayName },
                    new() { Content = row.TheaterName },
                    new() { Content = row.RecordType ? "Admin Giriş" : "Künye Giriş" },
                    new() { Content = row.CreatedAt?.ToLocalTime().ToString("dd.MM.yyyy HH:mm", CultureInfo.CurrentCulture) ?? "-" },
                    new()
                    {
                        ToggleUrl = $"/oyunlar/{row.PlayId:D}/juri-oylama-status",
                        ToggleChecked = row.JuriOylamaStatus,
                        AccessibleLabel = $"{row.PlayName} jüri oylama listesi statüsünü değiştir"
                    },
                    new()
                    {
                        ToggleUrl = $"/oyunlar/{row.PlayId:D}/kunye-giris-status",
                        ToggleChecked = row.KunyeGirisStatus,
                        AccessibleLabel = $"{row.PlayName} künye giriş sistemi statüsünü değiştir"
                    }
                ]
            };
        }).ToArray();

        return new ComplexTableViewModel
        {
            Id = "plays-table",
            ControllerName = "Management",
            ActionName = "Plays",
            DataActionName = "PlaysTable",
            CurrentTabKey = "plays",
            SearchPlaceholder = "Oyun veya tiyatro ara",
            MinimumTableWidth = 1280,
            IsNavigationColActive = true,
            AdditionalRouteValues = new Dictionary<string, string?>
            {
                [nameof(PlayTableQuery.JuryVotingStatus)] = FormatFilter(report.JuryVotingStatus),
                [nameof(PlayTableQuery.KunyeGirisStatus)] = FormatFilter(report.KunyeGirisStatus),
                [nameof(PlayTableQuery.RecordType)] = FormatFilter(report.RecordType)
            },
            Tabs =
            [
                new()
                {
                    Key = "plays",
                    Title = "Oyunlar",
                    Search = report.Search,
                    SortBy = report.SortBy,
                    SortDirection = report.SortDirection,
                    CurrentPage = report.CurrentPage,
                    PageSize = PlayTableViewModel.PageSize,
                    TotalCount = report.TotalCount,
                    EmptyMessage = "Arama ve filtre kriterlerine uygun oyun bulunamadı.",
                    Columns = Columns,
                    Rows = rows,
                    HeaderActions =
                    [
                        new()
                        {
                            Text = activeFilterCount > 0 ? $"Filtrele({activeFilterCount})" : "Filtrele",
                            IsButton = true,
                            PanelTarget = "play-filter-panel",
                            CssClass = activeFilterCount > 0 ? "is-active" : string.Empty
                        },
                        new() { Text = "Oyun Ekle", Icon = "/icons/plus.svg", Link = "/oyunlar/ekle" }
                    ]
                }
            ],
            SummaryContent =
            [
                new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
                new() { Text = " kayıt bulundu. " },
                new() { Text = report.JuryVotingEnabledCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
                new() { Text = " kayıt jüri tarafından oylanabilir." }
            ]
        };
    }

    private static string FormatFilter(bool? value) =>
        value.HasValue ? value.Value.ToString().ToLowerInvariant() : string.Empty;
}
