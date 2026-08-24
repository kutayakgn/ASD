using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;
using YKBAfife.Helpers;

namespace YKBAfife.Models.ViewModels;

public sealed class AddJuryViewModel
{
    [Required(ErrorMessage = "Kullanıcı adı zorunludur.")]
    [StringLength(UsernamePolicy.MaximumLength, MinimumLength = UsernamePolicy.MinimumLength,
        ErrorMessage = UsernamePolicy.LengthErrorMessage)]
    [RegularExpression(UsernamePolicy.Pattern, ErrorMessage = UsernamePolicy.FormatErrorMessage)]
    [Display(Name = "Kullanıcı Adı")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-posta adresi zorunludur.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi giriniz.")]
    [StringLength(255)]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Şifre zorunludur.")]
    [StringLength(PasswordPolicy.MaximumLength, MinimumLength = PasswordPolicy.MinimumLength,
        ErrorMessage = PasswordPolicy.ErrorMessage)]
    [RegularExpression(PasswordPolicy.Pattern, ErrorMessage = PasswordPolicy.ErrorMessage)]
    [DataType(DataType.Password)]
    [Display(Name = "Şifre")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Adı soyadı zorunludur.")]
    [StringLength(201, MinimumLength = 3)]
    [RegularExpression(@"^\s*\S+\s+\S+.*$", ErrorMessage = "Ad ve soyad bilgisini birlikte giriniz.")]
    [Display(Name = "Adı Soyadı")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Telefon numarası zorunludur.")]
    [RegularExpression(PhonePolicy.Pattern, ErrorMessage = PhonePolicy.ErrorMessage)]
    [StringLength(PhonePolicy.MaximumLength, MinimumLength = PhonePolicy.MinimumLength,
        ErrorMessage = PhonePolicy.ErrorMessage)]
    [Display(Name = "Telefon")]
    public string Phone { get; set; } = string.Empty;

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
    public bool? IsActive { get; set; } = true;

    [Display(Name = "Jüri Başkanı")]
    public bool IsJuryPresident { get; set; }

    [Display(Name = "Fotoğraf Ekle")]
    public IFormFile? Photo { get; set; }
}
