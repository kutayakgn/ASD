using System.ComponentModel.DataAnnotations;
using YKBAfife.Helpers;

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
    [Required(ErrorMessage = "Kullanıcı adı zorunludur.")]
    [StringLength(UsernamePolicy.MaximumLength, MinimumLength = UsernamePolicy.MinimumLength,
        ErrorMessage = UsernamePolicy.LengthErrorMessage)]
    [RegularExpression(UsernamePolicy.Pattern, ErrorMessage = UsernamePolicy.FormatErrorMessage)]
    [Display(Name = "Kullanıcı Adı")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-posta adresi zorunludur.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi giriniz.")]
    [RegularExpression(@"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$", ErrorMessage = "E-posta adresi Türkçe karakter içeremez.")]
    [StringLength(255)]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Adı soyadı zorunludur.")]
    [StringLength(201, MinimumLength = 3)]
    [RegularExpression(@"^\s*\S+\s+\S+.*$", ErrorMessage = "Ad ve soyad bilgisini birlikte giriniz.")]
    [Display(Name = "Adı Soyadı")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Şifre zorunludur.")]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "Şifre en az 8 karakter olmalıdır.")]
    [Display(Name = "Şifre")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
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
    public bool CanDelete { get; init; }
}

public static class AdminSortColumns
{
    public const string Username = "username";
    public const string FullName = "fullName";
}
