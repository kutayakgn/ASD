using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class EditAdminViewModel
{
    public Guid Id { get; set; }

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

    [StringLength(100, MinimumLength = 8, ErrorMessage = "Yeni \u015fifre en az 8 karakter olmal\u0131d\u0131r.")]
    [Display(Name = "\u015eifre")]
    public string? Password { get; set; }

    [Required(ErrorMessage = "Stat\u00fc se\u00e7imi zorunludur.")]
    [Display(Name = "Stat\u00fc")]
    public bool? IsActive { get; set; }
    public bool CanEditStatus { get; set; } = true;
}
