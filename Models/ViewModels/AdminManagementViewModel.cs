using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class AdminTableQuery
{
    public string Search { get; set; } = string.Empty;
    public string SortBy { get; set; } = AdminSortColumns.Username;
    public string SortDirection { get; set; } = "asc";
    public int Page { get; set; } = 1;
}

public sealed class AdminTableViewModel
{
    public const int PageSize = 10;
    public string Search { get; init; } = string.Empty;
    public string SortBy { get; init; } = AdminSortColumns.Username;
    public string SortDirection { get; init; } = "asc";
    public int CurrentPage { get; init; } = 1;
    public int TotalCount { get; init; }
    public IReadOnlyList<AdminTableRowViewModel> Rows { get; init; } = [];
}

public sealed class AdminTableRowViewModel
{
    public Guid UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

public sealed class AdminManagementViewModel
{
    public Components.ComplexTableViewModel Table { get; init; } = new();
}

public sealed class AddAdminViewModel
{
    [Required(ErrorMessage = "Kullan\u0131c\u0131 ad\u0131 zorunludur.")]
    [StringLength(100, MinimumLength = 3, ErrorMessage = "Kullan\u0131c\u0131 ad\u0131 3-100 karakter aras\u0131nda olmal\u0131d\u0131r.")]
    [RegularExpression(@"^[\p{L}\p{N}._-]+$", ErrorMessage = "Kullan\u0131c\u0131 ad\u0131 bo\u015fluk veya ._- d\u0131\u015f\u0131nda noktalama i\u015fareti i\u00e7eremez.")]
    [Display(Name = "Kullan\u0131c\u0131 Ad\u0131")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-posta adresi zorunludur.")]
    [EmailAddress(ErrorMessage = "Ge\u00e7erli bir e-posta adresi giriniz.")]
    [RegularExpression(@"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$", ErrorMessage = "E-posta adresi T\u00fcrk\u00e7e karakter i\u00e7eremez.")]
    [StringLength(255)]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Ad\u0131 soyad\u0131 zorunludur.")]
    [StringLength(201, MinimumLength = 3)]
    [RegularExpression(@"^\s*\S+\s+\S+.*$", ErrorMessage = "Ad ve soyad bilgisini birlikte giriniz.")]
    [Display(Name = "Ad\u0131 Soyad\u0131")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "\u015eifre zorunludur.")]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "\u015eifre en az 8 karakter olmal\u0131d\u0131r.")]
    [Display(Name = "\u015eifre")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Stat\u00fc se\u00e7imi zorunludur.")]
    [Display(Name = "Stat\u00fc")]
    public bool? IsActive { get; set; } = true;
}

public sealed class AdminDetailsViewModel
{
    public Guid Id { get; init; }
    public string Username { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public DateTime? CreatedAt { get; init; }
    public string CreatedByName { get; init; } = string.Empty;
}

public static class AdminSortColumns
{
    public const string Username = "username";
    public const string FullName = "fullName";
}
