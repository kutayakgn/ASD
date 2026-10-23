// Supplied jury implementation fixture, copied from docs/jury-panel-final/PasswordHashHelper.cs.
// Keep its original namespace and implementation so tests exercise both applications independently.
using System.Globalization;
using System.Security.Cryptography;

namespace YkbAfife.Business.Helpers;

public static class PasswordHashHelper
{
    private const string Algorithm = "pbkdf2-sha256";
    private const int IterationCount = 600_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    // Yalnızca mevcut kayıtları okuyup ilk başarılı girişte yükseltmek içindir.
    private const int LegacyIterationCount = 10_000;
    private const int LegacyHashSize = 20;

    public static string HashPassword(string password)
    {
        ArgumentNullException.ThrowIfNull(password);
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            IterationCount,
            HashAlgorithmName.SHA256,
            HashSize);

        return string.Join('$',
            Algorithm,
            IterationCount.ToString(CultureInfo.InvariantCulture),
            Convert.ToBase64String(salt),
            Convert.ToBase64String(hash));
    }

    public static bool VerifyPassword(string enteredPassword, string storedHash)
    {
        if (string.IsNullOrEmpty(enteredPassword) || string.IsNullOrWhiteSpace(storedHash))
        {
            return false;
        }

        return storedHash.StartsWith(Algorithm + '$', StringComparison.Ordinal)
            ? VerifyCurrent(enteredPassword, storedHash)
            : VerifyLegacy(enteredPassword, storedHash);
    }

    public static bool NeedsRehash(string storedHash)
    {
        if (!storedHash.StartsWith(Algorithm + '$', StringComparison.Ordinal))
        {
            return true;
        }

        var parts = storedHash.Split('$');
        return parts.Length != 4
            || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations)
            || iterations < IterationCount;
    }

    private static bool VerifyCurrent(string password, string storedHash)
    {
        try
        {
            var parts = storedHash.Split('$');
            if (parts.Length != 4
                || parts[0] != Algorithm
                || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations)
                || iterations < 100_000
                || iterations > 1_000_000)
            {
                return false;
            }

            var salt = Convert.FromBase64String(parts[2]);
            var expectedHash = Convert.FromBase64String(parts[3]);
            if (salt.Length != SaltSize || expectedHash.Length != HashSize)
            {
                return false;
            }

            var actualHash = Rfc2898DeriveBytes.Pbkdf2(
                password,
                salt,
                iterations,
                HashAlgorithmName.SHA256,
                expectedHash.Length);
            return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static bool VerifyLegacy(string password, string storedHash)
    {
        try
        {
            var bytes = Convert.FromBase64String(storedHash);
            if (bytes.Length != SaltSize + LegacyHashSize)
            {
                return false;
            }

            var salt = bytes[..SaltSize];
            var expectedHash = bytes[SaltSize..];
            var actualHash = Rfc2898DeriveBytes.Pbkdf2(
                password,
                salt,
                LegacyIterationCount,
                HashAlgorithmName.SHA1,
                LegacyHashSize);
            return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
