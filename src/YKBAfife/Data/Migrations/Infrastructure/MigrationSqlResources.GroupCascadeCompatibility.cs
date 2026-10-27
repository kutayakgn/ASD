using System.Security.Cryptography;
using System.Text;

namespace YKBAfife.Data.Migrations;

internal static partial class MigrationSqlResources
{
    private const string OriginalGroupCascadeBatchHash =
        "CA0250461DBE7FC24361C1B4BAC72A2E482498E890EE7E230A1A2697D3007403";
    private const string CompatibleGroupCascadeBatchHash = "3FF8058E7A78F70E70E746F89FB7CC058CA797AFB767507D52F6DAE38FF0E151";
    private const string GroupCascadeCompatibilityResource = "GroupCodeCascadeCompatibility.sql";

    /// <summary>
    /// A pending historical migration cannot reach a later corrective migration
    /// when its original installer creates duplicate cascading FK paths. Keep
    /// the released package and its integrity checks intact, and replace only
    /// that exact reviewed batch with a frozen, separately verified installer.
    /// The same compatibility rule applies when that batch is replayed by Down.
    /// </summary>
    private static string ApplyHistoricalGroupCascadeCompatibility(string command) =>
        ApplyHistoricalGroupCascadeCompatibility(command, Read);

    private static string ApplyHistoricalGroupCascadeCompatibility(
        string command, Func<string, string> readResource)
    {
        if (GroupCascadeBatchHash(command) != OriginalGroupCascadeBatchHash)
        {
            return command;
        }

        var replacement = readResource(GroupCascadeCompatibilityResource).Trim();
        if (GroupCascadeBatchHash(replacement) != CompatibleGroupCascadeBatchHash)
        {
            throw new InvalidOperationException(
                "The reviewed historical group-cascade compatibility resource failed its integrity check. " +
                "Deploy the matching complete application build; do not alter historical SQL packages.");
        }

        return replacement;
    }

    private static string GroupCascadeBatchHash(string command) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            command.Replace("\r\n", "\n", StringComparison.Ordinal).Trim())));
}
