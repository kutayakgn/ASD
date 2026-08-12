using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class ExpandDesignerCandidateRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

            migrationBuilder.Sql("""
                UPDATE candidate
                SET IsPublished = 0,
                    IsActive = 0,
                    IsCurrent = 0,
                    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                FROM dbo.PlayAwardCategories AS candidate
                INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                WHERE play.SourceFormId IS NOT NULL
                  AND candidate.AwardCategoryCode BETWEEN 1007 AND 1011
                  AND candidate.RoleCode = 0
                  AND candidate.IsPublished = 1;

                EXEC dbo.usp_SynchronizeFormsToPlays;
                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains the expanded category metadata,
            // separately synchronized candidates, and all historical rows.
        }
    }
}
