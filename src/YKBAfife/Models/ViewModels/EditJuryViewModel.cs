using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;
using YKBAfife.Helpers;

namespace YKBAfife.Models.ViewModels;

public sealed class EditJuryViewModel
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
    [StringLength(255)]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [StringLength(100, MinimumLength = 8, ErrorMessage = "Yeni şifre en az 8 karakter olmalıdır.")]
    [DataType(DataType.Password)]
    [Display(Name = "Şifre")]
    public string? Password { get; set; }

    [Required(ErrorMessage = "Adı soyadı zorunludur.")]
    [StringLength(201, MinimumLength = 3)]
    [RegularExpression(@"^\s*\S+\s+\S+.*$", ErrorMessage = "Ad ve soyad bilgisini birlikte giriniz.")]
    [Display(Name = "Adı Soyadı")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Telefon numarası zorunludur.")]
    [RegularExpression(@"^\d{10,11}$", ErrorMessage = "Telefon numarası 10 veya 11 rakamdan oluşmalıdır.")]
    [StringLength(11, MinimumLength = 10, ErrorMessage = "Telefon numarası 10 veya 11 rakamdan oluşmalıdır.")]
    [Display(Name = "Telefon")]
    public string Phone { get; set; } = string.Empty;

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
    public bool? IsActive { get; set; }

    [Display(Name = "Jüri Başkanı")]
    public bool IsJuryPresident { get; set; }

    [Display(Name = "Fotoğraf Ekle")]
    public IFormFile? Photo { get; set; }

    public bool RemovePhoto { get; set; }
    public bool HasExistingPhoto { get; set; }
    public string ExistingPhotoFileName { get; set; } = string.Empty;
    public string ExistingPhotoUrl { get; set; } = string.Empty;
}
