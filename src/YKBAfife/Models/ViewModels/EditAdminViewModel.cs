using System.ComponentModel.DataAnnotations;
using YKBAfife.Helpers;

namespace YKBAfife.Models.ViewModels;

public sealed class EditAdminViewModel
{
    public Guid Id { get; set; }

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

    [StringLength(100, MinimumLength = 8, ErrorMessage = "Yeni şifre en az 8 karakter olmalıdır.")]
    [Display(Name = "Şifre")]
    public string? Password { get; set; }

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
    public bool? IsActive { get; set; }
    public bool CanEditStatus { get; set; } = true;
}
