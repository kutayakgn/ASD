using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class PlayStatusSettingsRowViewModel
{
    public Guid Id { get; init; }
    public int StatusCode { get; init; }
    public string StatusName { get; init; } = string.Empty;
    public string StatusColor { get; init; } = string.Empty;
}

public sealed class PlayStatusDetailsViewModel
{
    public Guid Id { get; init; }
    public int StatusCode { get; init; }
    public string StatusName { get; init; } = string.Empty;
    public string StatusColor { get; init; } = string.Empty;
}

public sealed class EditPlayStatusViewModel
{
    public Guid Id { get; set; }
    public int StatusCode { get; set; }
    public string StatusName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Renk kodu zorunludur.")]
    [RegularExpression("^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$",
        ErrorMessage = "Renk kodu # ile başlamalı ve ardından 6 veya 8 hexadecimal karakter içermelidir.")]
    public string StatusColor { get; set; } = string.Empty;
}