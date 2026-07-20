using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class PlayWatchExcelExportFactory
{
    public static ExcelExportDocument Create(PlayWatchExportViewModel report, string title)
    {
        var juryColumns = BuildJuryColumns(report.Juries);
        var columns = new List<ExcelExportColumn>
        {
            new() { Header = "Oyun Adı", Width = 45 },
            new()
            {
                Header = "İzlenme Sayısı",
                Width = 18,
                Alignment = ExcelExportAlignment.Center
            }
        };

        columns.AddRange(juryColumns.Select(item => new ExcelExportColumn
        {
            Header = item.Header,
            Width = Math.Max(14, Math.Min(30, item.Header.Length + 4)),
            Alignment = ExcelExportAlignment.Center
        }));

        var rows = report.Rows.Select(row =>
        {
            var cells = new List<ExcelExportCell>
            {
                new() { Value = row.PlayName },
                new() { Value = row.ViewCount }
            };

            cells.AddRange(juryColumns.Select(item => new ExcelExportCell
            {
                Value = row.ViewerIds.Contains(item.Jury.Id) ? "İzledi" : string.Empty
            }));

            return (IReadOnlyList<ExcelExportCell>)cells;
        }).ToArray();

        return new ExcelExportDocument
        {
            WorksheetName = "Oyun İzlenmeleri",
            TableName = "OyunIzlenmeRaporu",
            Title = title,
            Columns = columns,
            Rows = rows,
            FooterLines = [$"Toplam kayıt sayısı: {rows.Length}"]
        };
    }

    private static IReadOnlyList<JuryColumn> BuildJuryColumns(
        IReadOnlyList<PlayWatchExportJuryViewModel> juries)
    {
        var usedHeaders = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "Oyun Adı",
            "İzlenme Sayısı"
        };
        var result = new List<JuryColumn>(juries.Count);

        foreach (var jury in juries)
        {
            var baseHeader = string.IsNullOrWhiteSpace(jury.FullName) ? "İsimsiz Jüri" : jury.FullName;
            var header = baseHeader;
            var sequence = 2;

            while (!usedHeaders.Add(header))
            {
                header = $"{baseHeader} ({sequence++})";
            }

            result.Add(new JuryColumn(jury, header));
        }

        return result;
    }

    private sealed record JuryColumn(PlayWatchExportJuryViewModel Jury, string Header);
}