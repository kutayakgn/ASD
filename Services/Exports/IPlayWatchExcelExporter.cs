using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Exports;

public interface IPlayWatchExcelExporter
{
    byte[] Export(IReadOnlyList<PlayWatchRowViewModel> rows, string worksheetTitle);
}
