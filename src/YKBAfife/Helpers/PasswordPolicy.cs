namespace YKBAfife.Helpers;

public static class PasswordPolicy
{
    public const int MinimumLength = 8;
    public const int MaximumLength = 100;
    public const string Pattern =
        @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!""#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~]).{8,100}$";
    public const string ErrorMessage =
        "Şifre 8-100 karakter arasında olmalı; en az bir büyük harf, bir küçük harf, bir rakam ve bir noktalama işareti içermelidir.";
}
