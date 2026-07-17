using YKBAfife.Models.Exports;

namespace YKBAfife.Services.Exports;

public interface IExcelExporter
{
    byte[] Export(ExcelExportDocument document);
}
