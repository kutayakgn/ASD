using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class RespectInactiveFormsForDirectorCandidates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                /* Repair invalid legacy/drifted director rows without making an
                   inactive Form source visible. Rows and votes remain physical. */
                UPDATE candidate
                SET IsPublished = 0,
                    IsActive = 0,
                    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                FROM dbo.PlayAwardCategories AS candidate
                INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                WHERE candidate.AwardCategoryCode = 1002
                  AND (candidate.IsPublished = 1 OR candidate.IsActive = 1)
                  AND
                  (
                      formRecord.IsPublished = 0
                      OR formRecord.IsActive = 0
                      OR play.IsPublished = 0
                      OR play.IsActive = 0
                  );

                /* Only effective source plays may have their mandatory director
                   candidate activated. */
                UPDATE candidate
                SET IsActive = 1,
                    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                FROM dbo.PlayAwardCategories AS candidate
                INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                WHERE candidate.AwardCategoryCode = 1002
                  AND candidate.IsPublished = 1
                  AND candidate.IsActive = 0
                  AND play.IsPublished = 1
                  AND play.IsActive = 1
                  AND
                  (
                      play.SourceFormId IS NULL
                      OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
                  );

                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains repaired soft-delete state and does
            // not reactivate candidates belonging to inactive Form sources.
        }
    }
}
