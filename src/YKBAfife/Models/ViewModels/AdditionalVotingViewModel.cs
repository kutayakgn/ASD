using System.ComponentModel.DataAnnotations;
using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class AdditionalVotingTableQuery
{
    public string SortBy { get; set; } = AdditionalVotingSortColumns.StartDate;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
}

public sealed class AdditionalVotingTableViewModel
{
    public const int PageSize = 10;
    public string SortBy { get; init; } = AdditionalVotingSortColumns.StartDate;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<AdditionalVotingRowViewModel> Rows { get; init; } = [];
}

public sealed class AdditionalVotingRowViewModel
{
    public Guid Id { get; init; }
    public DateOnly StartDate { get; init; }
    public DateOnly EndDate { get; init; }
    public bool AppliesToAllJuries { get; init; }
    public bool AppliesToAllPlays { get; init; }
    public int JuryCount { get; init; }
    public int PlayCount { get; init; }
    public int FirstVoteUserCount { get; init; }
    public int VoteUpdateUserCount { get; init; }
}

public sealed class AdditionalVotingFormViewModel : IValidatableObject
{
    public Guid? Id { get; set; }

    [Required(ErrorMessage = "Ek oylama başlangıç tarihi zorunludur.")]
    public DateOnly? StartDate { get; set; }

    [Required(ErrorMessage = "Ek oylama bitiş tarihi zorunludur.")]
    public DateOnly? EndDate { get; set; }

    public bool AppliesToAllJuries { get; set; }
    public bool AppliesToAllPlays { get; set; }
    public List<Guid> SelectedJuryIds { get; set; } = [];
    public List<Guid> SelectedPlayIds { get; set; } = [];
    public IReadOnlyList<AddPlayJuryGroupViewModel> JuryGroups { get; set; } = [];
    public IReadOnlyList<AdditionalVotingPlayOptionViewModel> PlayOptions { get; set; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (StartDate.HasValue && EndDate.HasValue && StartDate.Value >= EndDate.Value)
        {
            yield return new ValidationResult(
                "Ek oylama başlangıç tarihi bitiş tarihinden önce olmalıdır.",
                [nameof(StartDate), nameof(EndDate)]);
        }

        if (!AppliesToAllJuries && SelectedJuryIds.Count == 0)
        {
            yield return new ValidationResult("En az bir jüri seçmelisiniz.", [nameof(SelectedJuryIds)]);
        }

        if (!AppliesToAllPlays && SelectedPlayIds.Count == 0)
        {
            yield return new ValidationResult("En az bir oyun seçmelisiniz.", [nameof(SelectedPlayIds)]);
        }
    }
}

public sealed class AdditionalVotingPlayOptionViewModel
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
}

public sealed class AdditionalVotingDetailsViewModel
{
    public Guid Id { get; init; }
    public DateOnly StartDate { get; init; }
    public DateOnly EndDate { get; init; }
    public bool AppliesToAllJuries { get; init; }
    public bool AppliesToAllPlays { get; init; }
    public IReadOnlyList<string> JuryNames { get; init; } = [];
    public IReadOnlyList<string> PlayNames { get; init; } = [];
    public IReadOnlyList<string> FirstVoteUserNames { get; init; } = [];
    public IReadOnlyList<string> VoteUpdateUserNames { get; init; } = [];
}

public static class AdditionalVotingSortColumns
{
    public const string StartDate = "startDate";
    public const string EndDate = "endDate";
    public const string Juries = "juries";
    public const string Plays = "plays";
    public const string FirstVotes = "firstVotes";
    public const string VoteUpdates = "voteUpdates";
}
