using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using YKBAfife.Data;

// Exercise the real production reader, not a second copy of its hash algorithm.
// All inputs live in memory: these checks never connect to a database or edit history.
internal static class MigrationPayloadRuntimeRegression
{
    internal static void Run(Action<bool, string> assert)
    {
        var assembly = typeof(AfifeContext).Assembly;
        var resourcesType = assembly.GetType("YKBAfife.Data.Migrations.MigrationSqlResources", true)!;
        var reader = resourcesType.GetMethod("ReadVersionSection", BindingFlags.Static | BindingFlags.NonPublic,
            binder: null, [typeof(string), typeof(string), typeof(HashSet<string>), typeof(Func<string, string>)],
            modifiers: null) ?? throw new InvalidOperationException("The runtime SQL package test hook is missing.");
        var readEmbedded = resourcesType.GetMethod("Read", BindingFlags.Static | BindingFlags.Public)!;
        var packageNames = assembly.GetManifestResourceNames()
            .Where(name => name.Contains(".Migrations.Versions.", StringComparison.Ordinal) && name.EndsWith(".sql", StringComparison.Ordinal))
            .ToArray();
        var packages = packageNames.ToDictionary(
            name => name[(name.LastIndexOf(".Versions.", StringComparison.Ordinal) + ".Versions.".Length)..],
            name =>
            {
                using var stream = assembly.GetManifestResourceStream(name)!;
                using var text = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
                return text.ReadToEnd();
            }, StringComparer.Ordinal);
        assert(packages.Count >= 5, "Real immutable migration packages are embedded for transport regressions.");

        string Read(IReadOnlyDictionary<string, string> source, string version, string section) =>
            (string)reader.Invoke(null, [version, section, new HashSet<string>(StringComparer.Ordinal),
                (Func<string, string>)(name => source[name])])!;

        foreach (var package in packages)
        {
            var version = package.Key[..^4];
            var sections = Regex.Matches(package.Value, @"(?m)^-- <AFIFE:SHA256:(?<section>UP|DOWN|SEED)=")
                .Select(match => match.Groups["section"].Value).ToArray();
            foreach (var section in sections)
            {
                var baseline = (string)readEmbedded.Invoke(null, [$"{version}.{TitleCase(section)}.sql"])!;
                foreach (var transport in new[] { "LF", "CRLF", "mixed", "BOM+LF", "BOM+CRLF" })
                {
                    var transported = packages.ToDictionary(item => item.Key,
                        item => Transport(item.Value, transport), StringComparer.Ordinal);
                    var actual = Read(transported, version, section);
                    assert(Normalize(actual) == Normalize(baseline),
                        $"Runtime preserves {version}/{section} across {transport} checkout/transport, including references.");
                    assert(BatchCount(actual) == BatchCount(baseline),
                        $"Runtime preserves {version}/{section} SQL batches across {transport}.");
                }
            }
        }

        const string seedVersion = "JuryHomePageTableSettings_v_20261014130956";
        var seedFile = seedVersion + ".sql";
        var badSql = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = packages[seedFile].Replace("N'true', @Now", "N'false', @Now", StringComparison.Ordinal)
        };
        Rejects(() => Read(badSql, seedVersion, "SEED"), "hash mismatch", "Changed seed default is rejected.");
        var badUnicode = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = packages[seedFile].Replace("Jüri ana ekran", "Juri ana ekran", StringComparison.Ordinal)
        };
        Rejects(() => Read(badUnicode, seedVersion, "SEED"), "hash mismatch", "Changed Turkish Unicode content is rejected.");
        var badHash = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = Regex.Replace(packages[seedFile], @"(?m)^-- <AFIFE:SHA256:SEED=[A-F0-9]{64}>",
                "-- <AFIFE:SHA256:SEED=" + new string('0', 64) + ">")
        };
        Rejects(() => Read(badHash, seedVersion, "SEED"), "hash mismatch", "Corrupt historical digest is rejected.");
        var badBatches = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = packages[seedFile].Replace("-- <AFIFE:BATCHES:SEED=1>", "-- <AFIFE:BATCHES:SEED=2>", StringComparison.Ordinal)
        };
        Rejects(() => Read(badBatches, seedVersion, "SEED"), "batch count mismatch", "Corrupt batch metadata is rejected.");

        var duplicateSection = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = packages[seedFile] + $"\n-- <AFIFE:SEED:REFERENCE={seedVersion}:SEED>\n"
        };
        Rejects(() => Read(duplicateSection, seedVersion, "SEED"), "exactly one", "Ambiguous duplicate inline/reference sections are rejected.");
        var duplicateHash = new Dictionary<string, string>(packages, StringComparer.Ordinal)
        {
            [seedFile] = packages[seedFile] + "\n" + Regex.Match(packages[seedFile], @"(?m)^-- <AFIFE:SHA256:SEED=[A-F0-9]{64}>\r?$").Value
        };
        Rejects(() => Read(duplicateHash, seedVersion, "SEED"), "hash mismatch", "Duplicate digest metadata is rejected.");

        const string sql = "SELECT N'Jüri, ışık, ş, ğ, İ';\nGO\nSELECT 2;\n";
        foreach (var historicalEnding in new[] { "LF", "CRLF" })
        {
            var original = Transport(sql, historicalEnding);
            var synthetic = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Historic.sql"] = Package("UP", original),
                ["Reference.sql"] = Reference("UP", "Historic", "UP", original),
                ["Chain.sql"] = Reference("DOWN", "Reference", "UP", original)
            };
            foreach (var transport in new[] { "LF", "CRLF", "mixed", "BOM+LF", "BOM+CRLF" })
            {
                var transported = synthetic.ToDictionary(item => item.Key,
                    item => Transport(item.Value, transport), StringComparer.Ordinal);
                assert(Normalize(Read(transported, "Chain", "DOWN")) == Normalize(original),
                    $"Historic {historicalEnding} digest remains valid after {transport} through nested references.");
            }
        }
        var circular = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["CycleA.sql"] = Reference("UP", "CycleB", "UP", sql),
            ["CycleB.sql"] = Reference("UP", "CycleA", "UP", sql)
        };
        Rejects(() => Read(circular, "CycleA", "UP"), "Circular", "Circular SQL package references are rejected.");
        var badReference = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["Historic.sql"] = Package("UP", sql),
            ["Reference.sql"] = Reference("DOWN", "Historic", "UP", sql.Replace("SELECT 2", "SELECT 3", StringComparison.Ordinal))
        };
        Rejects(() => Read(badReference, "Reference", "DOWN"), "hash mismatch", "A reference must independently verify its own digest.");
        var badReferenceBatches = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["Historic.sql"] = Package("UP", sql),
            ["Reference.sql"] = Reference("DOWN", "Historic", "UP", sql).Replace("BATCHES:DOWN=2", "BATCHES:DOWN=3", StringComparison.Ordinal)
        };
        Rejects(() => Read(badReferenceBatches, "Reference", "DOWN"), "batch count mismatch", "A reference must independently verify its own batch count.");

        var canonicalPackage = Package("UP", sql);
        var rawHash = Hash(sql);
        var canonicalHash = Hash(Normalize(sql));
        foreach (var invalidMarker in new[]
        {
            $"-- <AFIFE:SHA256-LF:UP={rawHash}:{new string('0', 64)}>",
            $"-- <AFIFE:SHA256-LF:UP={new string('0', 64)}:{canonicalHash}>",
            $"-- <AFIFE:SHA256-LF:UP={rawHash}:malformed>"
        })
        {
            var corrupt = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Corrupt.sql"] = Regex.Replace(canonicalPackage, @"(?m)^-- <AFIFE:SHA256-LF:UP=.*$", invalidMarker)
            };
            Rejects(() => Read(corrupt, "Corrupt", "UP"), "hash mismatch",
                "Corrupt canonical metadata is rejected even when the original raw digest still matches.");
        }
        var duplicateMarker = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["Corrupt.sql"] = canonicalPackage + $"-- <AFIFE:SHA256-LF:UP={rawHash}:{canonicalHash}>\n"
        };
        Rejects(() => Read(duplicateMarker, "Corrupt", "UP"), "hash mismatch", "Duplicate canonical metadata is rejected.");
        var legacyPackage = Regex.Replace(canonicalPackage, @"(?m)^-- <AFIFE:SHA256-LF:UP=.*\n", "");
        var legacy = new Dictionary<string, string>(StringComparer.Ordinal) { ["Legacy.sql"] = legacyPackage };
        assert(Read(legacy, "Legacy", "UP") == sql, "A legacy package without canonical metadata still verifies its exact historical raw digest.");
        legacy["Legacy.sql"] = Transport(legacyPackage, "CRLF");
        Rejects(() => Read(legacy, "Legacy", "UP"), "hash mismatch", "Legacy packages without canonical metadata do not gain a hash bypass.");
        foreach (var mutation in new[]
        {
            sql.Replace("SELECT 2", "SELECT  2", StringComparison.Ordinal),
            " " + sql,
            sql.TrimEnd('\n'),
            sql.Replace("SELECT 2", "\uFEFFSELECT 2", StringComparison.Ordinal),
            sql.Replace("Jüri", "Ju\u0308ri", StringComparison.Ordinal)
        })
        {
            var tampered = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Strict.sql"] = canonicalPackage.Replace(sql, mutation, StringComparison.Ordinal)
            };
            Rejects(() => Read(tampered, "Strict", "UP"), "hash mismatch",
                "Canonical transport handling does not normalize spaces, trims, payload BOMs, or Unicode code points.");
        }

        void Rejects(Action action, string messagePart, string message)
        {
            Exception? failure = null;
            try { action(); }
            catch (Exception exception)
            {
                failure = exception;
                while (failure is TargetInvocationException { InnerException: not null } invocation)
                    failure = invocation.InnerException;
            }
            assert(failure is InvalidOperationException && failure.Message.Contains(messagePart, StringComparison.OrdinalIgnoreCase),
                message + (failure is null ? " No failure was raised." : $" Actual: {failure.Message}"));
        }
    }

    private static string TitleCase(string section) => section[0] + section[1..].ToLowerInvariant();
    private static string Normalize(string sql) => sql.Replace("\r\n", "\n", StringComparison.Ordinal);
    private static int BatchCount(string sql) => Regex.Split(sql, @"^\s*GO\s*(?:--.*)?$", RegexOptions.Multiline | RegexOptions.IgnoreCase)
        .Count(batch => !string.IsNullOrWhiteSpace(batch));
    private static string Hash(string sql) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
    private static string Package(string section, string sql) =>
        $"-- <AFIFE:SHA256:{section}={Hash(sql)}>\n-- <AFIFE:SHA256-LF:{section}={Hash(sql)}:{Hash(Normalize(sql))}>\n-- <AFIFE:BATCHES:{section}={BatchCount(sql)}>\n-- <AFIFE:{section}>\n{sql}\n-- </AFIFE:{section}>\n";
    private static string Reference(string section, string version, string targetSection, string sql) =>
        $"-- <AFIFE:SHA256:{section}={Hash(sql)}>\n-- <AFIFE:SHA256-LF:{section}={Hash(sql)}:{Hash(Normalize(sql))}>\n-- <AFIFE:BATCHES:{section}={BatchCount(sql)}>\n-- <AFIFE:{section}:REFERENCE={version}:{targetSection}>\n";

    private static string Transport(string text, string kind)
    {
        var normalized = Normalize(text).TrimStart('\uFEFF');
        if (kind.EndsWith("CRLF", StringComparison.Ordinal)) normalized = normalized.Replace("\n", "\r\n", StringComparison.Ordinal);
        else if (kind == "mixed")
        {
            var lines = normalized.Split('\n');
            normalized = string.Concat(lines.Select((line, index) => line +
                (index == lines.Length - 1 ? "" : index % 2 == 0 ? "\r\n" : "\n")));
        }
        return kind.StartsWith("BOM+", StringComparison.Ordinal) ? "\uFEFF" + normalized : normalized;
    }
}
