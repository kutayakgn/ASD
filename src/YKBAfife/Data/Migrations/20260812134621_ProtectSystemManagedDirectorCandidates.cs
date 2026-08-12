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
                UPDATE dbo.PlayAwardCategories
                SET IsActive = 1,
                    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                WHERE AwardCategoryCode = 1002
                  AND IsPublished = 1
                  AND IsActive = 0;
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
