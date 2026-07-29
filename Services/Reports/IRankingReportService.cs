using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public interface IRankingReportService
{
    Task<RankingTableViewModel> GetPageAsync(
        RankingTableQuery query,
        CancellationToken cancellationToken = default);

    Task<RankingVoteTableViewModel> GetVotesPageAsync(
        RankingVoteTableQuery query,
        CancellationToken cancellationToken = default);

    Task<RankingVoteTableViewModel> GetVotesExportAsync(
        RankingVoteTableQuery query,
        CancellationToken cancellationToken = default);

    Task<RankingTableViewModel> GetExportAsync(
        RankingTableQuery query,
        bool currentPageOnly,
        CancellationToken cancellationToken = default);
}
