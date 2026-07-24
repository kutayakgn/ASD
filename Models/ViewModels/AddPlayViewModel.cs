using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public class PlayFormViewModel
{
    [Required(ErrorMessage = "Oyun adı zorunludur.")]
    [StringLength(250, MinimumLength = 2, ErrorMessage = "Oyun adı 2-250 karakter arasında olmalıdır.")]
    [Display(Name = "Oyun Adı")]
    public string PlayName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Tiyatro adı zorunludur.")]
    [StringLength(250, MinimumLength = 2, ErrorMessage = "Tiyatro adı 2-250 karakter arasında olmalıdır.")]
    [Display(Name = "Tiyatro Adı")]
    public string TheaterName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Oyun statüsü zorunludur.")]
    [Display(Name = "Oyun Statüsü")]
    public int? StatusCode { get; set; }

    public List<Guid> SelectedJuryIds { get; set; } = [];
    public bool ConfirmSimilarPlay { get; set; }
    public IReadOnlyList<AddPlayJuryGroupViewModel> JuryGroups { get; set; } = [];
    public IReadOnlyList<AddPlayStatusOptionViewModel> StatusOptions { get; set; } = [];
}


public sealed class AddPlayViewModel : PlayFormViewModel { }

public sealed class EditPlayViewModel : PlayFormViewModel
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public bool RecordType { get; set; }
    public bool JuriOylamaStatus { get; set; }
    public bool KunyeGirisStatus { get; set; }
    public string RecordTypeDisplay => RecordType ? "Admin Giriş" : "Künye Giriş";
}
public sealed class AddPlayJuryGroupViewModel
{
    public string Key { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public IReadOnlyList<AddPlayJuryOptionViewModel> Juries { get; init; } = [];
}

public sealed class AddPlayJuryOptionViewModel
{
    public Guid Id { get; init; }
    public string FullName { get; init; } = string.Empty;
}

public sealed class AddPlayStatusOptionViewModel
{
    public int StatusCode { get; init; }
    public string StatusName { get; init; } = string.Empty;
    public string StatusColor { get; init; } = "#6b7280";
}
