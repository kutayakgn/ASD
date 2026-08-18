using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260818100000_V1_2_0_AllowJuryVisibilityForAllPlays")]
public sealed class V1_2_0_AllowJuryVisibilityForAllPlays : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            DROP TRIGGER IF EXISTS dbo.TR_Plays_NormalizeJuryVotingStatus;

            IF OBJECT_ID(N'dbo.CK_Plays_AdminRecord_StatusesDisabled', N'C') IS NOT NULL
            BEGIN
                ALTER TABLE dbo.Plays
                    DROP CONSTRAINT CK_Plays_AdminRecord_StatusesDisabled;
            END;

            IF OBJECT_ID(N'dbo.CK_Plays_AdminRecord_KunyeStatusDisabled', N'C') IS NULL
            BEGIN
                ALTER TABLE dbo.Plays WITH CHECK
                    ADD CONSTRAINT CK_Plays_AdminRecord_KunyeStatusDisabled
                    CHECK ([RecordType] = 0 OR [KunyeGirisStatus] = 0);

                ALTER TABLE dbo.Plays
                    CHECK CONSTRAINT CK_Plays_AdminRecord_KunyeStatusDisabled;
            END;
            """)
            .Annotation(
                MigrationSqlResources.ReviewedDataSafeSqlAnnotation,
                true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Jüri görünürlüğünü tekrar RecordType/StatusCode ile kapatmak mevcut
        // yayın kararlarını değiştireceğinden compatibility rollback yapılmaz.
    }
}
