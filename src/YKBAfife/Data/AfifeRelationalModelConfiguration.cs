using Microsoft.EntityFrameworkCore;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
    public static void Configure(ModelBuilder modelBuilder)
    {
        ConfigureReferenceKeys(modelBuilder);
        ConfigureRelationships(modelBuilder);
        ConfigureColumns(modelBuilder);
        ConfigureIndexes(modelBuilder);
        ConfigureChecks(modelBuilder);
        RemoveNonCanonicalConventionIndexes(modelBuilder);
    }
}
