using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

public partial class EnforceCategory1001TheaterIdentity : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Install the new invariant first so every concurrent write observes it.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

        migrationBuilder.Sql("""
            UPDATE candidate
            SET
                candidate.Candidate = play.TheaterName,
                candidate.Role = N'Tiyatro',
                candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE candidate.AwardCategoryCode = 1001
              AND play.RecordType = 0
              AND
              (
                  candidate.Candidate <> play.TheaterName
                  OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
              );
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Canonical candidate/role values are retained by compatibility rollback.
    }
}