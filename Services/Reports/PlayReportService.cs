using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Services.Reports;

public sealed class PlayReportService(AfifeContext context) : IPlayReportService
{
    public async Task<PlayTableViewModel> GetPageAsync(
        PlayTableQuery query,
        CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(query);
        var plays = context.Plays.AsNoTracking().Where(play => play.IsPublished);

        if (!string.IsNullOrWhiteSpace(normalized.Search))
        {
            var search = normalized.Search;
            plays = plays.Where(play =>
                play.PlayName.Contains(search) ||
                play.TheaterName.Contains(search));
        }

        if (normalized.JuryVotingStatus.HasValue)
        {
            plays = plays.Where(play => play.JuriOylamaStatus == normalized.JuryVotingStatus.Value);
        }

        if (normalized.KunyeGirisStatus.HasValue)
        {
            plays = plays.Where(play => play.KunyeGirisStatus == normalized.KunyeGirisStatus.Value);
        }

        if (normalized.RecordType.HasValue)
        {
            plays = plays.Where(play => play.RecordType == normalized.RecordType.Value);
        }

        var totalCount = await plays.CountAsync(cancellationToken);
        var juryVotingEnabledCount = await plays.CountAsync(play => play.JuriOylamaStatus, cancellationToken);
        var totalPages = Math.Max(1, (int)Math.Ceiling(totalCount / (double)PlayTableViewModel.PageSize));
        var currentPage = Math.Min(normalized.Page, totalPages);

        var rows = plays.Select(play => new PlayTableRowViewModel
        {
            PlayId = play.Id,
            PlayName = play.PlayName,
            TheaterName = play.TheaterName,
            RecordType = play.RecordType,
            CreatedAt = play.CreatedAt,
            JuriOylamaStatus = play.JuriOylamaStatus,
            KunyeGirisStatus = play.KunyeGirisStatus,
            Slug = play.Slug
        });

        var pageRows = await ApplyOrdering(rows, normalized.SortBy, normalized.SortDirection)
            .Skip((currentPage - 1) * PlayTableViewModel.PageSize)
            .Take(PlayTableViewModel.PageSize)
            .ToArrayAsync(cancellationToken);

        return new PlayTableViewModel
        {
            Search = normalized.Search,
            SortBy = normalized.SortBy,
            SortDirection = normalized.SortDirection,
            CurrentPage = currentPage,
            TotalCount = totalCount,
            JuryVotingEnabledCount = juryVotingEnabledCount,
            JuryVotingStatus = normalized.JuryVotingStatus,
            KunyeGirisStatus = normalized.KunyeGirisStatus,
            RecordType = normalized.RecordType,
            Rows = pageRows
        };
    }

    private static IOrderedQueryable<PlayTableRowViewModel> ApplyOrdering(
        IQueryable<PlayTableRowViewModel> rows,
        string sortBy,
        string sortDirection)
    {
        var descending = sortDirection == "desc";
        return sortBy switch
        {
            PlaySortColumns.TheaterName => descending
                ? rows.OrderByDescending(row => row.TheaterName).ThenBy(row => row.PlayId)
                : rows.OrderBy(row => row.TheaterName).ThenBy(row => row.PlayId),
            PlaySortColumns.RecordType => descending
                ? rows.OrderByDescending(row => row.RecordType).ThenBy(row => row.PlayName)
                : rows.OrderBy(row => row.RecordType).ThenBy(row => row.PlayName),
            PlaySortColumns.CreatedAt => descending
                ? rows.OrderByDescending(row => row.CreatedAt).ThenBy(row => row.PlayName)
                : rows.OrderBy(row => row.CreatedAt).ThenBy(row => row.PlayName),
            PlaySortColumns.JuryVotingStatus => descending
                ? rows.OrderByDescending(row => row.JuriOylamaStatus).ThenBy(row => row.PlayName)
                : rows.OrderBy(row => row.JuriOylamaStatus).ThenBy(row => row.PlayName),
            PlaySortColumns.KunyeGirisStatus => descending
                ? rows.OrderByDescending(row => row.KunyeGirisStatus).ThenBy(row => row.PlayName)
                : rows.OrderBy(row => row.KunyeGirisStatus).ThenBy(row => row.PlayName),
            _ => descending
                ? rows.OrderByDescending(row => row.PlayName).ThenBy(row => row.PlayId)
                : rows.OrderBy(row => row.PlayName).ThenBy(row => row.PlayId)
        };
    }

    private static PlayTableQuery Normalize(PlayTableQuery query)
    {
        var allowedSortColumns = new HashSet<string>(StringComparer.Ordinal)
        {
            PlaySortColumns.PlayName,
            PlaySortColumns.TheaterName,
            PlaySortColumns.RecordType,
            PlaySortColumns.CreatedAt,
            PlaySortColumns.JuryVotingStatus,
            PlaySortColumns.KunyeGirisStatus
        };

        return new PlayTableQuery
        {
            Search = (query.Search ?? string.Empty).Trim(),
            SortBy = allowedSortColumns.Contains(query.SortBy) ? query.SortBy : PlaySortColumns.PlayName,
            SortDirection = string.Equals(query.SortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc",
            Page = Math.Max(1, query.Page),
            JuryVotingStatus = query.JuryVotingStatus,
            KunyeGirisStatus = query.KunyeGirisStatus,
            RecordType = query.RecordType
        };
    }
}
