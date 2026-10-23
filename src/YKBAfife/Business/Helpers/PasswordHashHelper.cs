using System.Globalization;
using System.Security.Cryptography;

namespace YKBAfife.Business.Helpers;

public static class PasswordHashHelper
{
    private const int SaltSize = 16;
    private const int HashSize = 20;
    private const int IterationCount = 10_000;
    private const string ModernAlgorithm = "pbkdf2-sha256";
    private const int ModernHashSize = 32;

    public static string HashPassword(string password)
    {
        ArgumentNullException.ThrowIfNull(password);

        // Deployed jury versions still read this legacy wire format. Accept
        // newer jury hashes below without changing new-password compatibility
        // or rewriting any stored hash during login or application startup.
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            IterationCount,
            HashAlgorithmName.SHA1,
            HashSize);

        var hashBytes = new byte[SaltSize + HashSize];
        salt.CopyTo(hashBytes, 0);
        hash.CopyTo(hashBytes, SaltSize);

        return Convert.ToBase64String(hashBytes);
    }

    public static bool VerifyPassword(string enteredPassword, string storedHash)
    {
        if (string.IsNullOrEmpty(enteredPassword) || string.IsNullOrWhiteSpace(storedHash))
        {
            return false;
        }

        return storedHash.StartsWith(ModernAlgorithm + '$', StringComparison.Ordinal)
            ? VerifyModern(enteredPassword, storedHash)
            : VerifyLegacy(enteredPassword, storedHash);
    }

    private static bool VerifyModern(string password, string storedHash)
    {
        try
        {
            var parts = storedHash.Split('$');
            if (parts.Length != 4 || parts[0] != ModernAlgorithm ||
                !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations) ||
                iterations is < 100_000 or > 1_000_000)
            {
                return false;
            }

            var salt = Convert.FromBase64String(parts[2]);
            var expectedHash = Convert.FromBase64String(parts[3]);
            if (salt.Length != SaltSize || expectedHash.Length != ModernHashSize)
                return false;

            var actualHash = Rfc2898DeriveBytes.Pbkdf2(
                password, salt, iterations, HashAlgorithmName.SHA256, ModernHashSize);
            return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static bool VerifyLegacy(string enteredPassword, string storedHash)
    {
        try
        {
            var hashBytes = Convert.FromBase64String(storedHash);
            if (hashBytes.Length != SaltSize + HashSize)
            {
                return false;
            }

            var salt = hashBytes[..SaltSize];
            var storedPasswordHash = hashBytes[SaltSize..];
            var computedHash = Rfc2898DeriveBytes.Pbkdf2(
                enteredPassword,
                salt,
                IterationCount,
                HashAlgorithmName.SHA1,
                HashSize);

            return CryptographicOperations.FixedTimeEquals(computedHash, storedPasswordHash);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
