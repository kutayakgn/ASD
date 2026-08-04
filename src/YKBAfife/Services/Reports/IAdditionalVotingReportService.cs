namespace YKBAfife.Services.Reports;

public interface IAdditionalVotingReportService
{
    Task<YKBAfife.Models.ViewModels.AdditionalVotingTableViewModel> GetPageAsync(
        YKBAfife.Models.ViewModels.AdditionalVotingTableQuery query,
        CancellationToken cancellationToken = default);
}
