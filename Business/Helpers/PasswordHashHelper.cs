using System.Security.Cryptography;

namespace YKBAfife.Business.Helpers;

public static class PasswordHashHelper
{
    private const int SaltSize = 16;
    private const int HashSize = 20;
    private const int IterationCount = 10_000;

    public static string HashPassword(string password)
    {
        ArgumentNullException.ThrowIfNull(password);

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
        if (string.IsNullOrWhiteSpace(enteredPassword) || string.IsNullOrWhiteSpace(storedHash))
        {
            return false;
        }

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
