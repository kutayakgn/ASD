using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class AddCandidateInputModel
{
    [Required]
    public string Mode { get; set; } = "new";

    [Required(ErrorMessage = "Oyun se\u00E7imi zorunludur.")]
    public Guid? PlayId { get; set; }

    [Required(ErrorMessage = "\u00D6d\u00FCl kategorisi se\u00E7imi zorunludur.")]
    public int? AwardCategoryCode { get; set; }

    [Required(ErrorMessage = "Aday\u0131n ad\u0131 ve soyad\u0131 zorunludur.")]
    [StringLength(250, MinimumLength = 2, ErrorMessage = "Ad\u0131 soyad\u0131 en az 2 karakter olmal\u0131d\u0131r.")]
    public string Candidate { get; set; } = string.Empty;

    [StringLength(200)]
    public string? Role { get; set; }

    [Required(ErrorMessage = "Stat\u00FC se\u00E7imi zorunludur.")]
    public bool? IsActive { get; set; } = true;
}