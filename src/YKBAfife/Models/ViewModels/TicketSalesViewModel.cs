using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class TicketSalesTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = TicketSalesSortColumns.Date;
    public string SortDirection { get; set; } = "desc";
    public int Page { get; set; } = 1;
}

public sealed class TicketSalesTableViewModel
{
    public const int PageSize = 10;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = TicketSalesSortColumns.Date;
    public string SortDirection { get; init; } = "desc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<TicketSaleRowViewModel> Rows { get; init; } = [];
}

public sealed class TicketSaleRowViewModel
{
    public Guid Id { get; init; }
    public string JuryName { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;
    public DateTime? Date { get; init; }
    public decimal TicketFee { get; init; }
}

public sealed class TicketSalesViewModel
{
    public Components.ComplexTableViewModel Table { get; init; } = new();
}

public sealed class EditTicketFeeViewModel
{
    public Guid Id { get; init; }
    public string JuryName { get; init; } = string.Empty;
    public string PlayName { get; init; } = string.Empty;

    [Required(ErrorMessage = "Bilet ücreti zorunludur.")]
    [Display(Name = "Bilet Ücreti")]
    public decimal TicketFee { get; set; }
}

public static class TicketSalesSortColumns
{
    public const string Jury = "jury";
    public const string Play = "play";
    public const string Date = "date";
    public const string TicketFee = "ticketFee";
}
