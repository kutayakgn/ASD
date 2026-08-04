using System.Globalization;
using System.Text;

namespace YKBAfife.Helpers;

public static class SlugHelper
{
    public static string Resolve(string? storedSlug, string name)
    {
        return string.IsNullOrWhiteSpace(storedSlug)
            ? Create(name)
            : storedSlug.Trim();
    }

    public static string Create(string value)
    {
        var normalizedTurkish = value
            .Replace('ç', 'c').Replace('Ç', 'C')
            .Replace('ğ', 'g').Replace('Ğ', 'G')
            .Replace('ı', 'i').Replace('İ', 'I')
            .Replace('ö', 'o').Replace('Ö', 'O')
            .Replace('ş', 's').Replace('Ş', 'S')
            .Replace('ü', 'u').Replace('Ü', 'U');
        var decomposed = normalizedTurkish.Normalize(NormalizationForm.FormD);
        var result = new StringBuilder(decomposed.Length);
        var pendingSeparator = false;

        foreach (var character in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (char.IsAsciiLetterOrDigit(character))
            {
                if (pendingSeparator && result.Length > 0)
                {
                    result.Append('-');
                }

                result.Append(char.ToLowerInvariant(character));
                pendingSeparator = false;
            }
            else
            {
                pendingSeparator = result.Length > 0;
            }
        }

        return result.Length == 0 ? "oyun" : result.ToString();
    }
}
