namespace YKBAfife.Helpers;

public static class UsernamePolicy
{
    public const int MinimumLength = 3;
    public const int MaximumLength = 30;
    public const string Pattern = @"^[A-Za-z0-9._]+$";
    public const string LengthErrorMessage = "Kullanıcı adı 3-30 karakter arasında olmalıdır.";
    public const string FormatErrorMessage =
        "Kullanıcı adı yalnızca İngilizce harf, rakam, nokta ve alt çizgi içerebilir; boşluk içeremez.";
}
