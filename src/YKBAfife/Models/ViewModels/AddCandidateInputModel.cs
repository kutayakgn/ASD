using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class AddCandidateInputModel
{
    [Required]
    public string Mode { get; set; } = "new";

    [Required(ErrorMessage = "Oyun seçimi zorunludur.")]
    public Guid? PlayId { get; set; }

    [Required(ErrorMessage = "Ödül kategorisi seçimi zorunludur.")]
    public int? AwardCategoryCode { get; set; }

    public Guid? ReplacedCandidateId { get; set; }

    [Required(ErrorMessage = "Adayın adı ve soyadı zorunludur.")]
    [StringLength(250, MinimumLength = 2, ErrorMessage = "Adı soyadı en az 2 karakter olmalıdır.")]
    public string Candidate { get; set; } = string.Empty;

    [StringLength(200)]
    public string? Role { get; set; }

    public IFormFile? Photo { get; set; }

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    public bool? IsActive { get; set; } = true;
}