using System.Globalization;
using System.Text;
using System.Text.Encodings.Web;
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
        new() { Title = "Jüri Oylama Listesi", Key = PlaySortColumns.JuryVotingStatus, ColWidth = 10, IsSortable = false, CssClass = "play-toggle-column" },
        new() { Title = "Künye Giriş Sistemi", Key = PlaySortColumns.KunyeGirisStatus, ColWidth = 10, IsSortable = false, CssClass = "play-toggle-column" }
    ];

    public static ComplexTableViewModel Create(PlayTableViewModel report)
    {
        var activeFilterCount = new[] { report.JuryVotingStatus, report.KunyeGirisStatus, report.RecordType }
            .Count(value => value.HasValue);
        var rows = report.Rows.Select(row =>
        {
            var slug = SlugHelper.Resolve(row.Slug, row.PlayName);
            var detailsUrl = $"/oyunlar/{Uri.EscapeDataString(slug)}?returnUrl=%2Foyunlar";
            var encodedPlayName = HtmlEncoder.Default.Encode(row.PlayName);
            var playNameContent = BuildPlayNameContent(row, encodedPlayName);
            return new ComplexTableRowViewModel
            {
                Id = $"play-{row.PlayId:N}",
                Link = detailsUrl,
                NavigationUrl = detailsUrl,
                NavigationAccessibleLabel = $"{row.PlayName} oyun detayına git",
                Cells =
                [
                    new() { Content = playNameContent, IsHtml = row.IsNew || row.HasSimilarPlay },
                    new() { Content = row.TheaterName },
                    new() { Content = row.RecordType ? "Admin Giriş" : "Künye Giriş" },
                    new() { Content = row.CreatedAt?.ToString("dd.MM.yyyy HH:mm", CultureInfo.CurrentCulture) ?? "-" },
                    new()
                    {
                        ToggleUrl = $"/oyunlar/{row.PlayId:D}/juri-oylama-status",
                        ToggleChecked = !row.RecordType && row.StatusCode == 1 && row.JuriOylamaStatus,
                        ToggleDisabled = row.RecordType || row.StatusCode != 1,
                        CssClass = "play-toggle-cell",
                        AccessibleLabel = $"{row.PlayName} jüri oylama listesi statüsünü değiştir"
                    },
                    new()
                    {
                        ToggleUrl = $"/oyunlar/{row.PlayId:D}/kunye-giris-status",
                        ToggleChecked = !row.RecordType && row.KunyeGirisStatus,
                        ToggleDisabled = row.RecordType,
                        CssClass = "play-toggle-cell",
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
                            Text = activeFilterCount > 0 ? $"Filtrele ({activeFilterCount})" : "Filtrele",
                            IsButton = true,
                            PanelTarget = "play-filter-panel",
                            Icon="/icons/filter.svg",
                            CssClass = activeFilterCount > 0 ? "is-active bordered" : "bordered"
                        },
                        new() { Text = "Oyun Ekle", Icon = "/icons/plus.svg", Link = "/oyunlar/ekle" }
                    ]
                }
            ],
            SummaryContent =
            [
                new() { Text = report.TotalCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
                 new() { Text = " kayıt", IsEmphasized = true },
                new() { Text = " bulundu. " },
                new() { Text = report.JuryVotingEnabledCount.ToString(CultureInfo.CurrentCulture), IsEmphasized = true },
                new() { Text = " kayıt", IsEmphasized = true },
                new() { Text = " jüri tarafından oylanabilir." }
            ]
        };
    }

    private static string BuildPlayNameContent(PlayTableRowViewModel row, string encodedPlayName)
    {
        if (!row.IsNew && !row.HasSimilarPlay)
        {
            return row.PlayName;
        }

        var markers = new StringBuilder();
        if (row.IsNew)
        {
            markers.Append("<span class=\"play-new-tag\">Yeni</span>");
        }

        if (row.HasSimilarPlay && row.SimilarPlays.Count > 0)
        {
            var links = string.Join(", ", row.SimilarPlays.Select(similarPlay =>
            {
                var slug = SlugHelper.Resolve(similarPlay.Slug, similarPlay.PlayName);
                var href = HtmlEncoder.Default.Encode(
                    $"/oyunlar/{Uri.EscapeDataString(slug)}?returnUrl=%2Foyunlar");
                var name = HtmlEncoder.Default.Encode(similarPlay.PlayName);
                return $"<a href=\"{href}\">{name}</a>";
            }));

            markers.Append($$"""
                <span class="play-similar-warning">
                    <button type="button"
                            class="play-similar-warning-button"
                            aria-label="Benzer isimde oyun mevcut"
                            aria-expanded="false"
                            data-play-similar-trigger>
                        <img src="/icons/yellow-info-circle-filled.svg" alt="" aria-hidden="true" />
                    </button>
                    <template data-play-similar-content>
                        <span>Benzer isimde oyun mevcut: </span>{{links}}
                    </template>
                </span>
                """);
        }

        return $"<span class=\"play-name-with-tag\"><span>{encodedPlayName}</span>{markers}</span>";
    }

    private static string FormatFilter(bool? value) =>
        value.HasValue ? value.Value.ToString().ToLowerInvariant() : string.Empty;
}
