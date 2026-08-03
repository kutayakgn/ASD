using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface ISeasonSettingsReportService
{
    Task<SeasonSettingsTableViewModel> GetPageAsync(
        SeasonSettingsTableQuery query,
        CancellationToken cancellationToken = default);
}
