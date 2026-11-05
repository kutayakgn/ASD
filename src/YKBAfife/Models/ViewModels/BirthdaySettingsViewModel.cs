using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class BirthdaySettingsViewModel
{
    [Required(ErrorMessage = "Doğum günü mesajı zorunludur.")]
    [StringLength(200, ErrorMessage = "Doğum günü mesajı en fazla 200 karakter olabilir.")]
    [Display(Name = "Mesaj")]
    public string Message { get; set; } = string.Empty;

    [Required(ErrorMessage = "Gösterim süresi zorunludur.")]
    [Range(0, 10, ErrorMessage = "Gösterim süresi 0 ile 10 gün arasında olmalıdır.")]
    [Display(Name = "Gösterim Süresi (Gün)")]
    public int? DisplayDays { get; set; }
}
