using System.ComponentModel.DataAnnotations;

namespace YKBAfife.Models.ViewModels;

public sealed class LoginViewModel
{
    [Required(ErrorMessage = "Kullanıcı adı zorunludur.")]
    [Display(Name = "Kullanıcı adı")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Şifre zorunludur.")]
    [DataType(DataType.Password)]
    [Display(Name = "Şifre")]
    public string Password { get; set; } = string.Empty;


    public string? ReturnUrl { get; set; }
}
