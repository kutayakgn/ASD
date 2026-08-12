using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class RepairFormCandidateSchemaOrdering : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'dbo.Form', N'U') IS NULL
                    THROW 52420, N'Form aday şeması onarılamadı: dbo.Form tablosu bulunamadı.', 1;

                IF COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
                    EXEC sys.sp_executesql
                        N'ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;';

                IF COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
                    THROW 52421, N'Form aday şeması onarılamadı: YoungGenerationArtist kolonu oluşturulamadı.', 1;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
            MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");

            migrationBuilder.Sql("""
                EXEC dbo.usp_SynchronizeFormsToPlays;
                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains the additive column, synchronized
            // candidate/image history, and repaired programmable objects.
        }
    }
}
