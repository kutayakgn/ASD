namespace YKBAfife.Helpers;

public static class PhonePolicy
{
    public const int MinimumLength = 10;
    public const int MaximumLength = 11;
    public const string Pattern = @"^[0-9]{10,11}$";
    public const string HtmlPattern = @"[0-9]{10,11}";
    public const string ErrorMessage = "Telefon numarası 10 veya 11 rakamdan oluşmalıdır.";
}
