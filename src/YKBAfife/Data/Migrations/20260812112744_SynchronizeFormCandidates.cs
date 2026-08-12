using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class SynchronizeFormCandidates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
                    ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
            MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");

            migrationBuilder.Sql("EXEC dbo.usp_SynchronizeFormsToPlays;")
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains the additive Form field and all
            // synchronized candidate/image history.
        }
    }
}
