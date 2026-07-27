using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace YKBAfife.Models.ViewModels;

public sealed class EditCandidateViewModel
{
    public Guid Id { get; set; }
    public string PlayName { get; set; } = string.Empty;
    public string PlaySlug { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Adı Soyadı alanı zorunludur.")]
    [StringLength(250, MinimumLength = 2, ErrorMessage = "Adı Soyadı alanı 2 ile 250 karakter arasında olmalıdır.")]
    [Display(Name = "Adı Soyadı")]
    public string Candidate { get; set; } = string.Empty;

    [StringLength(200, ErrorMessage = "Rol Adı en fazla 200 karakter olabilir.")]
    [Display(Name = "Rol Adı")]
    public string? Role { get; set; }

    [Required(ErrorMessage = "Statü seçimi zorunludur.")]
    [Display(Name = "Statü")]
    public bool? IsActive { get; set; }

    [Display(Name = "Fotoğraf Ekle")]
    public IFormFile? Photo { get; set; }

    public bool RemovePhoto { get; set; }
    public bool HasRoleAndPhoto { get; set; }
    public bool HasExistingPhoto { get; set; }
    public string ExistingPhotoFileName { get; set; } = string.Empty;
    public string ExistingPhotoUrl { get; set; } = string.Empty;
    public string OriginalRole { get; set; } = string.Empty;
    public bool ConfirmRoleGroupUpdate { get; set; }
    public IReadOnlyList<RelatedCandidateViewModel> RelatedCandidates { get; set; } = [];
    public IReadOnlyList<string> OtherRoleNames { get; set; } = [];
}

public sealed class RelatedCandidateViewModel
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Url { get; init; } = string.Empty;
}
