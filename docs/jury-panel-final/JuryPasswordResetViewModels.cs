using System.ComponentModel.DataAnnotations;

namespace YkbAfife.Domain.Model.Data.JuryVoting;

public sealed class JuryForgotPasswordViewModel
{
    [Required(ErrorMessage = "E-posta adresi zorunludur.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi girin.")]
    [StringLength(254, ErrorMessage = "E-posta adresi en fazla 254 karakter olabilir.")]
    public string Email { get; set; } = string.Empty;
}

public sealed class JuryResetPasswordViewModel
{
    public const string PasswordPattern = @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[.,*!+\-@]).{8,100}$";

    [Required]
    [StringLength(200)]
    public string Token { get; set; } = string.Empty;

    [Required(ErrorMessage = "Yeni şifre zorunludur.")]
    [DataType(DataType.Password)]
    [RegularExpression(PasswordPattern,
        ErrorMessage = "Şifre 8-100 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter (.,*!+-@) içermelidir.")]
    public string NewPassword { get; set; } = string.Empty;

    [Required(ErrorMessage = "Yeni şifre tekrarı zorunludur.")]
    [DataType(DataType.Password)]
    [StringLength(100, MinimumLength = 8,
        ErrorMessage = "Şifre tekrarı 8-100 karakter arasında olmalıdır.")]
    [Compare(nameof(NewPassword), ErrorMessage = "Şifreler eşleşmiyor.")]
    public string ConfirmPassword { get; set; } = string.Empty;
}

public enum JuryVotingResetPasswordResult
{
    Success,
    InvalidOrExpiredToken
}
