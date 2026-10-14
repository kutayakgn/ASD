using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
    private static void ConfigureChecks(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>().ToTable("Users", "dbo", t =>
        {
            t.HasCheckConstraint(
                "CK_Users_JuryPresident",
                "[IsJuryPresident] = 0 OR ([RoleCode] = 2 AND [IsActive] = 1)");
            t.HasCheckConstraint(
                "CK_Users_Username_InstagramFormat",
                "LEN([Username]) BETWEEN 3 AND 30 AND " +
                "DATALENGTH([Username]) = LEN([Username]) * 2 AND " +
                "[Username] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Za-z0-9._]%'");
        });
        modelBuilder.Entity<Play>().ToTable("Plays", "dbo", t =>
        {
            t.UseSqlOutputClause(false);
            t.HasCheckConstraint("CK_Plays_AdminRecord_StatusCode", "[RecordType] = 0 OR [StatusCode] <> 1");
            t.HasCheckConstraint("CK_Plays_AdminRecord_KunyeStatusDisabled", "[RecordType] = 0 OR [KunyeGirisStatus] = 0");
            t.HasCheckConstraint("CK_Plays_KunyeMustRemainPublished", "[RecordType] = 1 OR [IsPublished] = 1");
            t.HasCheckConstraint("CK_Plays_SourceFormRequiresKunye", "[SourceFormId] IS NULL OR [RecordType] = 0");
        });
        modelBuilder.Entity<Ranking>().ToTable("Rankings", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Rankings_ArithmeticRank", "[ArithmeticRank] IS NULL OR [ArithmeticRank] > 0");
            t.HasCheckConstraint("CK_Rankings_TrimmedRank", "[TrimmedRank] IS NULL OR [TrimmedRank] > 0");
            t.HasCheckConstraint("CK_Rankings_ConfidenceValue", "[ConfidenceValue] IS NULL OR ([ConfidenceValue] >= 1 AND [ConfidenceValue] <= 4)");
            t.HasCheckConstraint("CK_Rankings_NumberOfActiveVote", "[NumberOfActiveVote] >= 0");
        });
        modelBuilder.Entity<Season>().ToTable("Seasons", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Seasons_SeasonDateRange", "[SeasonStartDate] < [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_KunyeRegistrationDateRange", "[KunyeRegistrationStartDate] >= [SeasonStartDate] AND [KunyeRegistrationStartDate] < [KunyeRegistrationEndDate] AND [KunyeRegistrationEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_VotingDateRange", "[VotingStartDate] >= [SeasonStartDate] AND [VotingStartDate] < [VotingEndDate] AND [VotingEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_NonNegativeCounts", "[PlayCount] >= 0 AND [ActivePlayCount] >= 0 AND [VoteCount] >= 0");
        });
    }
}
