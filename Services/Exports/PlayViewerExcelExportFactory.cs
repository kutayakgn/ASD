using YKBAfife.Models.Exports;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public static class PlayViewerExcelExportFactory
{
    public static ExcelExportDocument Create(
        string playName,
        IReadOnlyList<PlayViewerRowViewModel> viewers)
    {
        return new ExcelExportDocument
        {
            WorksheetName = "İzleyen Jüriler",
            TableName = "OyunuIzleyenJuriler",
            Title = $"{playName} - İzleyen Jüri Üyeleri",
            Columns = [new ExcelExportColumn { Header = "Jüri Adı Soyadı", Width = 34 }],
            Rows = viewers
                .Select(viewer => (IReadOnlyList<ExcelExportCell>)
                    [new ExcelExportCell { Value = viewer.FullName }])
                .ToArray(),
            FooterLines = [$"Toplam kayıt sayısı: {viewers.Count}"]
        };
    }
}
