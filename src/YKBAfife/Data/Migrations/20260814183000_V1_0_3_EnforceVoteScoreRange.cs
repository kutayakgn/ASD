using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260814183000_V1_0_3_EnforceVoteScoreRange")]
public sealed class V1_0_3_EnforceVoteScoreRange : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            IF EXISTS
            (
                SELECT 1
                FROM dbo.JuryVotes
                WHERE Score < 1 OR Score > 10
            )
            BEGIN
                THROW 51215,
                    N'CK_JuryVotes_Score eklenemedi: 1-10 aralığı dışında mevcut oy puanı var.',
                    1;
            END;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        migrationBuilder.AddCheckConstraint(
            name: "CK_JuryVotes_Score",
            schema: "dbo",
            table: "JuryVotes",
            sql: "[Score] >= 1 AND [Score] <= 10");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropCheckConstraint(
            name: "CK_JuryVotes_Score",
            schema: "dbo",
            table: "JuryVotes");
    }
}
