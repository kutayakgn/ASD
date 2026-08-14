using System.Text.Encodings.Web;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public static class PlayStatusSettingsComplexTableFactory
{
    private const string TabKey = "play-status-settings";

    public static ComplexTableViewModel Create(IReadOnlyList<PlayStatusSettingsRowViewModel> rows) => new()
    {
        Id = "play-status-settings-table",
        ControllerName = "Management",
        ActionName = "VotingSettings",
        CurrentTabKey = TabKey,
        ShowHeading = false,
        ShowSearch = false,
        IsEditableRows = true,
        MinimumTableWidth = 680,
        Tabs =
        [
            new ComplexTableTabViewModel
            {
                Key = TabKey,
                Title = "",
                PageSize = Math.Max(1, rows.Count),
                TotalCount = rows.Count,
                EmptyMessage = "Tanımlı oyun statüsü bulunamadı.",
                Columns =
                [
                    new() { Title = "Statü Kodu", Key = "statusCode", ColWidth = 10, IsSortable = false },
                    new() { Title = "Statü Adı", Key = "statusName", ColWidth = 45, IsSortable = false },
                    new() { Title = "Rengi", Key = "statusColor", ColWidth = 45, IsSortable = false }
                ],
                Rows = rows.Select(row => new ComplexTableRowViewModel
                {
                    Id = $"play-status-{row.Id:N}",
                    Link = $"/diger-ayarlar/oyun-statuler/{row.Id}",
                    EditUrl = $"/diger-ayarlar/oyun-statuler/{row.Id}/duzenle",
                    EditAccessibleLabel = $"{row.StatusName} oyun statüsünü düzenle",
                    Cells =
                    [
                        Cell(row.StatusCode.ToString()),
                        Cell(row.StatusName),
                        ColorCell(row.StatusColor)
                    ]
                }).ToArray()
            }
        ]
    };

    private static ComplexTableCellViewModel Cell(string value) => new() { Content = value };

    private static ComplexTableCellViewModel ColorCell(string color)
    {
        var safeColor = IsValidColor(color) ? color : "#6B7280";
        var encodedColor = HtmlEncoder.Default.Encode(safeColor);
        return new ComplexTableCellViewModel
        {
            IsHtml = true,
            CssClass = "play-status-color-cell",
            Content = $"<span class=\"play-status-color-value\"><span class=\"play-status-color-dot\" style=\"background-color:{encodedColor}\" aria-hidden=\"true\"></span>{encodedColor}</span>"
        };
    }

    private static bool IsValidColor(string value) =>
        value.Length is 7 or 9 && value[0] == '#' && value.Skip(1).All(Uri.IsHexDigit);
}
