using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace YKBAfife.Models.ViewModels;

public sealed class BlacklistTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = BlacklistSortColumns.CreatedOn;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
}

public sealed class BlacklistTableViewModel
{
    public const int PageSize = 10;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = BlacklistSortColumns.CreatedOn;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<BlacklistRowViewModel> Rows { get; init; } = [];
}

public sealed class BlacklistRowViewModel
{
    public Guid Id { get; init; }
    public string JuryName { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public DateTime CreatedOn { get; init; }
    public string CreatedByName { get; init; } = string.Empty;
}

public sealed class BlacklistViewModel
{
    public Components.ComplexTableViewModel Table { get; init; } = new();
}

public sealed class AddBlacklistViewModel
{
    [Required(ErrorMessage = "Jüri seçimi zorunludur.")]
    [Display(Name = "Jüri")]
    public Guid? JuryId { get; set; }

    [Required(ErrorMessage = "Oyun seçimi zorunludur.")]
    [Display(Name = "Oyun")]
    public Guid? PlayId { get; set; }

    public IReadOnlyList<SelectListItem> Juries { get; set; } = [];
    public IReadOnlyList<SelectListItem> Plays { get; set; } = [];
}

public static class BlacklistSortColumns
{
    public const string Jury = "jury";
    public const string Play = "play";
    public const string CreatedOn = "createdOn";
    public const string CreatedBy = "createdBy";
}
