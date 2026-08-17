using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class ProtectSystemManagedDirectorCandidates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
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
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains protected director candidates and
            // does not re-enable destructive management behavior.
        }
    }
}
