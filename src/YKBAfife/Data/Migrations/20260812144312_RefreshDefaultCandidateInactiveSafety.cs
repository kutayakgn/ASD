using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class RefreshDefaultCandidateInactiveSafety : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

            migrationBuilder.Sql("""
                DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

                /* Fire the refreshed system-category trigger only for Kunye plays
                   whose 1001 row is missing or has visibility inconsistent with
                   the owning Play/Form. */
                UPDATE play
                SET UpdatedAt = @Now
                FROM dbo.Plays AS play
                LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                OUTER APPLY
                (
                    SELECT TOP (1)
                        candidate.IsPublished,
                        candidate.IsActive
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.PlayId = play.Id
                      AND candidate.AwardCategoryCode = 1001
                      AND candidate.RoleCode = 0
                    ORDER BY candidate.IsCurrent DESC, candidate.Id
                ) AS defaultCandidate
                CROSS APPLY
                (
                    SELECT CONVERT(bit, CASE
                        WHEN play.IsPublished = 1
                         AND play.IsActive = 1
                         AND
                         (
                             play.SourceFormId IS NULL
                             OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
                         ) THEN 1 ELSE 0 END) AS ShouldBeVisible
                ) AS expected
                WHERE play.RecordType = 0
                  AND
                  (
                      defaultCandidate.IsPublished IS NULL
                      OR defaultCandidate.IsPublished <> expected.ShouldBeVisible
                      OR defaultCandidate.IsActive <> expected.ShouldBeVisible
                  );

                EXEC dbo.usp_SynchronizeFormsToPlays;
                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains repaired 1001 rows and does not
            // republish categories belonging to inactive Form sources.
        }
    }
}
