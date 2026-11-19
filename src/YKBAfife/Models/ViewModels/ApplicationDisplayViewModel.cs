using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class ApplicationDisplayViewModel
{
    public int? OriginalIndex { get; set; }

    [Required(ErrorMessage = "Gösterim yeri zorunludur.")]
    [Display(Name = "Gösterim Yeri")]
    public string Location { get; set; } = string.Empty;

    [Required(ErrorMessage = "Gösterim tarihi zorunludur.")]
    [DataType(DataType.Date)]
    [Display(Name = "Tarih")]
    public DateOnly? Date { get; set; }

    [DataType(DataType.Time)]
    [Display(Name = "Saat")]
    public TimeOnly? Time { get; set; }
}
