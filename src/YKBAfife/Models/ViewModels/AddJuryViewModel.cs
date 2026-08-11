using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace YKBAfife.Models.ViewModels;

public sealed class AddJuryViewModel
{
    [Required(ErrorMessage = "Kullanıcı adı zorunludur.")]
    [StringLength(100, MinimumLength = 3, ErrorMessage = "Kullanıcı adı 3-100 karakter arasında olmalıdır.")]
    [Display(Name = "Kullanıcı Adı")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-posta adresi zorunludur.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi giriniz.")]
    [StringLength(255)]
    [Display(Name = "E-posta")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Şifre zorunludur.")]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "Şifre en az 8 karakter olmalıdır.")]
    [DataType(DataType.Password)]
    [Display(Name = "Şifre")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Adı soyadı zorunludur.")]
    [StringLength(201, MinimumLength = 3)]
    [RegularExpression(@"^\s*\S+\s+\S+.*$", ErrorMessage = "Ad ve soyad bilgisini birlikte giriniz.")]
    [Display(Name = "Adı Soyadı")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Telefon numarası zorunludur.")]
    [Phone(ErrorMessage = "Geçerli bir telefon numarası giriniz.")]
    [StringLength(30)]
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
