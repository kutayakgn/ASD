using System.ComponentModel.DataAnnotations;
using YKBAfife.Models.Components;

namespace YKBAfife.Models.ViewModels;

public sealed class SeasonSettingsTableQuery
{
    public string SortBy { get; set; } = SeasonSettingsSortColumns.Season;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
}

public sealed class SeasonSettingsTableViewModel
{
    public const int PageSize = 10;

    public string SortBy { get; init; } = SeasonSettingsSortColumns.Season;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<SeasonSettingsRowViewModel> Rows { get; init; } = [];
}

public sealed class SeasonSettingsRowViewModel
{
    public Guid Id { get; init; }
    public DateOnly SeasonStartDate { get; init; }
    public DateOnly KunyeRegistrationStartDate { get; init; }
    public DateOnly KunyeRegistrationEndDate { get; init; }
    public DateOnly VotingStartDate { get; init; }
    public DateOnly VotingEndDate { get; init; }
    public DateOnly SeasonEndDate { get; init; }
    public string SeasonName => $"{SeasonStartDate.Year}/{SeasonEndDate.Year}";
}

public sealed class SeasonSettingsViewModel
{
    public ComplexTableViewModel Table { get; init; } = new();
}

public sealed class SeasonDetailsViewModel
{
    public Guid Id { get; init; }
    public DateOnly SeasonStartDate { get; init; }
    public DateOnly KunyeRegistrationStartDate { get; init; }
    public DateOnly KunyeRegistrationEndDate { get; init; }
    public DateOnly VotingStartDate { get; init; }
    public DateOnly VotingEndDate { get; init; }
    public DateOnly SeasonEndDate { get; init; }
    public string SeasonName => $"{SeasonStartDate.Year}/{SeasonEndDate.Year}";
}

public sealed class SeasonDateRangeViewModel
{
    public Guid Id { get; init; }
    public DateOnly SeasonStartDate { get; init; }
    public DateOnly SeasonEndDate { get; init; }
    public string SeasonName => $"{SeasonStartDate.Year}/{SeasonEndDate.Year}";
}

public sealed class SeasonFormViewModel : IValidatableObject
{
    public Guid? Id { get; set; }
    public IReadOnlyList<SeasonDateRangeViewModel> OtherPublishedSeasons { get; set; } = [];

    [Required(ErrorMessage = "Sezon başlangıç tarihi zorunludur.")]
    [Display(Name = "Sezon Başlangıç Tarihi")]
    public DateOnly? SeasonStartDate { get; set; }

    [Required(ErrorMessage = "Künye başlangıç tarihi zorunludur.")]
    [Display(Name = "Künye Başlangıç Tarihi")]
    public DateOnly? KunyeRegistrationStartDate { get; set; }

    [Required(ErrorMessage = "Künye bitiş tarihi zorunludur.")]
    [Display(Name = "Künye Bitiş Tarihi")]
    public DateOnly? KunyeRegistrationEndDate { get; set; }

    [Required(ErrorMessage = "Oylama başlangıç tarihi zorunludur.")]
    [Display(Name = "Oylama Başlangıç Tarihi")]
    public DateOnly? VotingStartDate { get; set; }

    [Required(ErrorMessage = "Oylama bitiş tarihi zorunludur.")]
    [Display(Name = "Oylama Bitiş Tarihi")]
    public DateOnly? VotingEndDate { get; set; }

    [Required(ErrorMessage = "Sezon bitiş tarihi zorunludur.")]
    [Display(Name = "Sezon Bitiş Tarihi")]
    public DateOnly? SeasonEndDate { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!SeasonStartDate.HasValue || !SeasonEndDate.HasValue ||
            !KunyeRegistrationStartDate.HasValue || !KunyeRegistrationEndDate.HasValue ||
            !VotingStartDate.HasValue || !VotingEndDate.HasValue)
        {
            yield break;
        }

        var seasonStart = SeasonStartDate.Value;
        var seasonEnd = SeasonEndDate.Value;
        var kunyeStart = KunyeRegistrationStartDate.Value;
        var kunyeEnd = KunyeRegistrationEndDate.Value;
        var votingStart = VotingStartDate.Value;
        var votingEnd = VotingEndDate.Value;

        if (seasonStart >= seasonEnd)
        {
            yield return new ValidationResult(
                "Sezon başlangıç tarihi sezon bitiş tarihinden önce olmalıdır.",
                [nameof(SeasonStartDate), nameof(SeasonEndDate)]);
        }

        if (kunyeStart < seasonStart)
        {
            yield return new ValidationResult(
                "Künye kayıt başlangıç tarihi sezon başlangıç tarihinden önce olamaz.",
                [nameof(KunyeRegistrationStartDate)]);
        }

        if (kunyeEnd <= kunyeStart)
        {
            yield return new ValidationResult(
                "Künye kayıt bitiş tarihi künye kayıt başlangıç tarihinden sonra olmalıdır.",
                [nameof(KunyeRegistrationEndDate)]);
        }

        if (kunyeEnd > seasonEnd)
        {
            yield return new ValidationResult(
                "Künye kayıt bitiş tarihi sezon bitiş tarihinden sonra olamaz.",
                [nameof(KunyeRegistrationEndDate)]);
        }

        if (votingStart < seasonStart || votingStart > seasonEnd)
        {
            yield return new ValidationResult(
                "Oylama başlangıç tarihi sezon tarihleri arasında olmalıdır.",
                [nameof(VotingStartDate)]);
        }

        if (votingEnd < seasonStart || votingEnd > seasonEnd)
        {
            yield return new ValidationResult(
                "Oylama bitiş tarihi sezon tarihleri arasında olmalıdır.",
                [nameof(VotingEndDate)]);
        }

        if (votingStart >= votingEnd)
        {
            yield return new ValidationResult(
                "Oylama başlangıç tarihi oylama bitiş tarihinden önce olmalıdır.",
                [nameof(VotingStartDate), nameof(VotingEndDate)]);
        }
    }
}

public static class SeasonSettingsSortColumns
{
    public const string Season = "season";
    public const string SeasonStartDate = "seasonStartDate";
    public const string KunyeRegistrationStartDate = "kunyeRegistrationStartDate";
    public const string KunyeRegistrationEndDate = "kunyeRegistrationEndDate";
    public const string VotingStartDate = "votingStartDate";
    public const string VotingEndDate = "votingEndDate";
    public const string SeasonEndDate = "seasonEndDate";
}
