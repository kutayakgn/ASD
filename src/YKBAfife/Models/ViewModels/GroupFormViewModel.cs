using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class GroupFormViewModel
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "Grup kodu zorunludur.")]
    [Display(Name = "Code")]
    public int? Code { get; set; }

    [Required(ErrorMessage = "Grup adı zorunludur.")]
    [StringLength(100, ErrorMessage = "Grup adı en fazla 100 karakter olabilir.")]
    [Display(Name = "GroupName")]
    public string GroupName { get; set; } = string.Empty;
}

public sealed class GroupSettingsRowViewModel
{
    public Guid Id { get; init; }
    public int Code { get; init; }
    public string GroupName { get; init; } = string.Empty;
}
