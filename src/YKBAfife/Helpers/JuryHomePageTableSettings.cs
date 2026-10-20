namespace YKBAfife.Helpers;

/// <summary>Stable integration keys; changing a display title never renames a Config row.</summary>
public static class JuryHomePageTableSettings
{
    public const string JuryTable = "HomePageJuryTableEnabled";
    public const string MissionTable = "HomePageMissionTableEnabled";
    public const string MostWatchedTable = "HomePageMostWatchedTableEnabled";
    public const string LeastWatchedTable = "HomePageLeastWatchedTableEnabled";

    public static IReadOnlyList<JuryHomePageTableDefinition> Definitions { get; } =
        Array.AsReadOnly(new[]
        {
            new JuryHomePageTableDefinition(JuryTable, "Jüri Üyeleri"),
            new JuryHomePageTableDefinition(MissionTable, "Görev Oyunları"),
            new JuryHomePageTableDefinition(MostWatchedTable, "Çok İzlenen Oyunlar"),
            new JuryHomePageTableDefinition(LeastWatchedTable, "Az İzlenen Oyunlar")
        });

    public static bool IsKnown(string? name) =>
        Definitions.Any(definition => string.Equals(definition.Name, name, StringComparison.Ordinal));

    public static bool IsEnabled(string? value) =>
        bool.TryParse(value, out var enabled) && enabled;

    internal const string NameFilter = "[ConfigName] IN ('HomePageJuryTableEnabled', 'HomePageMissionTableEnabled', 'HomePageMostWatchedTableEnabled', 'HomePageLeastWatchedTableEnabled')";
    internal const string ValueCheck = "NOT (" + NameFilter + ") OR " +
        "([IsPublished] = 1 AND [ConfigValue] COLLATE Latin1_General_100_BIN2 IN ('true', 'false') AND " +
        "DATALENGTH([ConfigValue]) = CASE WHEN [ConfigValue] COLLATE Latin1_General_100_BIN2 = 'true' THEN 8 ELSE 10 END)";
}

public sealed record JuryHomePageTableDefinition(string Name, string Title);
