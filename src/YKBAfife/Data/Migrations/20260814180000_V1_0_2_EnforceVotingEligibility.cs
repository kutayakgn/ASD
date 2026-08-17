using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260814180000_V1_0_2_EnforceVotingEligibility")]
public sealed class V1_0_2_EnforceVotingEligibility : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

        migrationBuilder.Sql("""
            DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

            UPDATE play
            SET JuriOylamaStatus = 0,
                UpdatedAt = @Now
            FROM dbo.Plays AS play
            WHERE play.RecordType = 0
              AND play.StatusCode <> 1
              AND play.JuriOylamaStatus = 1;

            UPDATE vote
            SET IsPublished = 0,
                IsActive = 0,
                UpdatedAt = @Now
            FROM dbo.JuryVotes AS vote
            INNER JOIN dbo.PlayAwardCategories AS candidate
                ON candidate.Id = vote.PlayAwardCategoryId
            INNER JOIN dbo.Blacklist AS blacklist
                ON blacklist.JuryId = vote.JuryId
               AND blacklist.PlayId = candidate.PlayId
               AND blacklist.IsPublished = 1
            WHERE vote.IsPublished = 1
               OR vote.IsActive = 1;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Compatibility rollback keeps normalized play statuses and unpublished
        // blacklisted votes; restoring either would recreate invalid live data.
    }
}
