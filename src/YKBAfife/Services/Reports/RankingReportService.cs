using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class RankingReportService(AfifeContext context) : IRankingReportService
{
    private static readonly int[] AllowedPageSizes = [5, 10, 15, 20];

    public async Task<RankingTableViewModel> GetPageAsync(
        RankingTableQuery query,
        CancellationToken cancellationToken = default) =>
        await BuildAsync(query, currentPageOnly: true, cancellationToken);

    public async Task<RankingTableViewModel> GetExportAsync(
        RankingTableQuery query,
        bool currentPageOnly,
        CancellationToken cancellationToken = default) =>
        await BuildAsync(query, currentPageOnly, cancellationToken);

    private async Task<RankingTableViewModel> BuildAsync(
        RankingTableQuery query,
        bool currentPageOnly,
        CancellationToken cancellationToken)
    {
        var categories = await context.AwardCategories
            .AsNoTracking()
            .OrderBy(category => category.CategoryCode)
            .Select(category => new RankingCategoryOptionViewModel
            {
                CategoryCode = category.CategoryCode,
                CategoryName = category.CategoryName,
                HasRoleAndPhoto = category.HasRoleAndPhoto
            })
            .ToArrayAsync(cancellationToken);

        var normalized = Normalize(query, categories);
        var selectedCategory = categories.First(category =>
            category.CategoryCode == normalized.CategoryCode);

        var source =
            from ranking in context.Rankings.AsNoTracking()
            join candidate in context.PlayAwardCategories.AsNoTracking()
                on ranking.PlayAwardCategoryId equals candidate.Id
            join play in context.Plays.AsNoTracking()
                on ranking.PlayId equals play.Id
            where candidate.AwardCategoryCode == normalized.CategoryCode
            select new RankingData
            {
                PlayAwardCategoryId = candidate.Id,
                CategoryName = selectedCategory.CategoryName,
                CandidateName = candidate.Candidate,
                TheaterName = play.TheaterName,
                PlayName = play.PlayName,
                NumberOfActiveVote = ranking.NumberOfActiveVote,
                ArithmeticMean = ranking.ArithmeticMean,
                TrimmedMean = ranking.TrimmedMean,
                ArithmeticVariance = ranking.ArithmeticVariance,
                ConfidenceValue = ranking.ConfidenceValue
            };

        var totalCount = await source.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)normalized.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);
        var ordered = ApplyOrdering(source, normalized.RankingType);
        var offset = currentPageOnly ? (currentPage - 1) * normalized.PageSize : 0;
        var take = currentPageOnly ? normalized.PageSize : Math.Max(totalCount, 1);
        var data = await ordered.Skip(offset).Take(take).ToArrayAsync(cancellationToken);

        var rows = data.Select((row, index) => new RankingRowViewModel
        {
            Position = offset + index + 1,
            PlayAwardCategoryId = row.PlayAwardCategoryId,
            CategoryName = row.CategoryName,
            DisplayName = selectedCategory.HasRoleAndPhoto ? row.CandidateName : row.TheaterName,
            PlayName = row.PlayName,
            TotalScore = row.ArithmeticMean.HasValue
                ? Convert.ToInt32(Math.Round(row.ArithmeticMean.Value * row.NumberOfActiveVote))
                : 0,
            ViewCount = row.NumberOfActiveVote,
            Variance = row.ArithmeticVariance,
            ConfidenceValue = row.ConfidenceValue,
            MetricValue = normalized.RankingType switch
            {
                RankingTypes.Arithmetic => row.ArithmeticMean,
                RankingTypes.Confidence => row.ConfidenceValue,
                _ => row.TrimmedMean
            }
        }).ToArray();

        return new RankingTableViewModel
        {
            Tab = normalized.Tab,
            RankingType = normalized.RankingType,
            CategoryCode = normalized.CategoryCode,
            CategoryHasRoleAndPhoto = selectedCategory.HasRoleAndPhoto,
            PageSize = normalized.PageSize,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Categories = categories,
            Rows = rows
        };
    }

    public async Task<RankingVoteTableViewModel> GetVotesPageAsync(
        RankingVoteTableQuery query,
        CancellationToken cancellationToken = default) =>
        await BuildVotesAsync(query, currentPageOnly: true, cancellationToken);

    public async Task<RankingVoteTableViewModel> GetVotesExportAsync(
        RankingVoteTableQuery query,
        CancellationToken cancellationToken = default) =>
        await BuildVotesAsync(
            query,
            currentPageOnly: false,
            cancellationToken);

    private async Task<RankingVoteTableViewModel> BuildVotesAsync(
        RankingVoteTableQuery query,
        bool currentPageOnly,
        CancellationToken cancellationToken)
    {
        var contextData = await (
            from candidate in context.PlayAwardCategories.AsNoTracking()
            join play in context.Plays.AsNoTracking() on candidate.PlayId equals play.Id
            where candidate.Id == query.PlayAwardCategoryId
            select new { play.PlayName })
            .SingleOrDefaultAsync(cancellationToken);
        if (contextData is null)
        {
            return new RankingVoteTableViewModel { PlayAwardCategoryId = query.PlayAwardCategoryId };
        }

        var votes =
            from vote in context.JuryVotes.AsNoTracking()
            join jury in context.Users.AsNoTracking() on vote.JuryId equals jury.Id
            where vote.PlayAwardCategoryId == query.PlayAwardCategoryId && vote.IsActive
            select new RankingVoteRowViewModel
            {
                VoteId = vote.Id,
                JuryFullName = (jury.FirstName + " " + jury.LastName).Trim(),
                Score = vote.Score
            };
        var sortBy = query.SortBy == RankingVoteSortColumns.Score
            ? RankingVoteSortColumns.Score
            : RankingVoteSortColumns.JuryName;
        var direction = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase)
            ? "desc"
            : "asc";
        var ordered = sortBy == RankingVoteSortColumns.Score
            ? direction == "desc"
                ? votes.OrderByDescending(row => row.Score).ThenBy(row => row.JuryFullName)
                : votes.OrderBy(row => row.Score).ThenBy(row => row.JuryFullName)
            : direction == "desc"
                ? votes.OrderByDescending(row => row.JuryFullName).ThenByDescending(row => row.Score)
                : votes.OrderBy(row => row.JuryFullName).ThenByDescending(row => row.Score);
        var totalCount = await votes.CountAsync(cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)RankingVoteTableViewModel.PageSize));
        var currentPage = Math.Min(Math.Max(1, query.Page), totalPages);
        var rows = currentPageOnly
            ? await ordered.Skip((currentPage - 1) * RankingVoteTableViewModel.PageSize)
                .Take(RankingVoteTableViewModel.PageSize).ToArrayAsync(cancellationToken)
            : await ordered.ToArrayAsync(cancellationToken);

        return new RankingVoteTableViewModel
        {
            PlayAwardCategoryId = query.PlayAwardCategoryId,
            PlayName = contextData.PlayName,
            SortBy = sortBy,
            SortDirection = direction,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            Rows = rows
        };
    }
    private static IOrderedQueryable<RankingData> ApplyOrdering(
        IQueryable<RankingData> source,
        string rankingType) => rankingType switch
        {
            RankingTypes.Arithmetic => source
                .OrderBy(row => row.ArithmeticMean == null)
                .ThenByDescending(row => row.ArithmeticMean)
                .ThenBy(row => row.CandidateName)
                .ThenBy(row => row.PlayName),
            RankingTypes.Confidence => source
                .OrderBy(row => row.ConfidenceValue == null)
                .ThenByDescending(row => row.ConfidenceValue)
                .ThenByDescending(row => row.TrimmedMean)
                .ThenBy(row => row.CandidateName)
                .ThenBy(row => row.PlayName),
            _ => source
                .OrderBy(row => row.TrimmedMean == null)
                .ThenByDescending(row => row.TrimmedMean)
                .ThenBy(row => row.CandidateName)
                .ThenBy(row => row.PlayName)
        };

    private static RankingTableQuery Normalize(
        RankingTableQuery query,
        IReadOnlyList<RankingCategoryOptionViewModel> categories)
    {
        if (categories.Count == 0)
        {
            throw new InvalidOperationException("Yayınlanmış ödül kategorisi bulunamadı.");
        }

        var tab = RankingTabs.All.Contains(query.Tab) ? query.Tab : RankingTabs.CategoryTrim;
        var rankingType = tab switch
        {
            RankingTabs.CategoryArithmetic => RankingTypes.Arithmetic,
            RankingTabs.Confidence => RankingTypes.Confidence,
            RankingTabs.AllGames when RankingTypes.All.Contains(query.RankingType) => query.RankingType,
            _ => RankingTypes.Trimmed
        };
        var categoryCode = categories.Any(category => category.CategoryCode == query.CategoryCode)
            ? query.CategoryCode
            : categories.Any(category => category.CategoryCode == 1001)
                ? 1001
                : categories[0].CategoryCode;

        return new RankingTableQuery
        {
            Tab = tab,
            RankingType = rankingType,
            CategoryCode = categoryCode,
            PageSize = AllowedPageSizes.Contains(query.PageSize) ? query.PageSize : 10,
            Page = Math.Max(1, query.Page)
        };
    }

    private sealed class RankingData
    {
        public Guid PlayAwardCategoryId { get; init; }
        public string CategoryName { get; init; } = string.Empty;
        public string CandidateName { get; init; } = string.Empty;
        public string TheaterName { get; init; } = string.Empty;
        public string PlayName { get; init; } = string.Empty;
        public int NumberOfActiveVote { get; init; }
        public double? ArithmeticMean { get; init; }
        public double? TrimmedMean { get; init; }
        public double? ArithmeticVariance { get; init; }
        public int? ConfidenceValue { get; init; }
    }
}
