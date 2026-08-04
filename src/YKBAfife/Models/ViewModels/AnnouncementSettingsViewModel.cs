using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class AnnouncementSettingsRowViewModel
{
    public Guid Id { get; init; }
    public int AnnouncementLocationId { get; init; }
    public string Text { get; init; } = string.Empty;
}

public sealed class AnnouncementDetailsViewModel
{
    public Guid Id { get; init; }
    public int AnnouncementLocationId { get; init; }
    public string Text { get; init; } = string.Empty;
    public string ButtonText { get; init; } = string.Empty;
    public string ButtonLink { get; init; } = string.Empty;
    public string BackgroundColor { get; init; } = string.Empty;
    public bool HasImage { get; init; }
    public bool HasBackgroundImage { get; init; }
}

public sealed class EditAnnouncementViewModel
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "Duyuru konum kimliği zorunludur.")]
    [Range(1, int.MaxValue, ErrorMessage = "Duyuru konum kimliği 1 veya daha büyük olmalıdır.")]
    [Display(Name = "Duyuru Konum ID")]
    public int AnnouncementLocationId { get; set; }

    [StringLength(255, ErrorMessage = "Duyuru metni en fazla 255 karakter olabilir.")]
    [Display(Name = "Duyuru Metni")]
    public string? Text { get; set; }

    [StringLength(255, ErrorMessage = "Buton metni en fazla 255 karakter olabilir.")]
    [Display(Name = "Buton Metni")]
    public string? ButtonText { get; set; }

    [StringLength(2048, ErrorMessage = "Buton bağlantısı en fazla 2048 karakter olabilir.")]
    [Display(Name = "Buton Bağlantısı")]
    public string? ButtonLink { get; set; }

    [RegularExpression("^$|^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$",
        ErrorMessage = "Arka plan rengi # ile başlamalı ve 6 veya 8 hexadecimal karakter içermelidir.")]
    [Display(Name = "Arka Plan Rengi")]
    public string? BackgroundColor { get; set; }

    [Display(Name = "Görsel")]
    public IFormFile? Image { get; set; }

    [Display(Name = "Arka Plan Görseli")]
    public IFormFile? BackgroundImage { get; set; }

    public bool RemoveImage { get; set; }
    public bool RemoveBackgroundImage { get; set; }
    public bool HasExistingImage { get; set; }
    public bool HasExistingBackgroundImage { get; set; }
    public string ExistingImageFileName { get; set; } = string.Empty;
    public string ExistingBackgroundImageFileName { get; set; } = string.Empty;
    public string ExistingImageUrl { get; set; } = string.Empty;
    public string ExistingBackgroundImageUrl { get; set; } = string.Empty;
}
