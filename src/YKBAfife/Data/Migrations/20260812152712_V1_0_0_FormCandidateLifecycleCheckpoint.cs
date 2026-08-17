using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class V1_0_0_FormCandidateLifecycleCheckpoint : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF COL_LENGTH(N'dbo.PlayAwardCategories', N'SourceFormCandidateOrder') IS NULL
                    EXEC sys.sp_executesql
                        N'ALTER TABLE dbo.PlayAwardCategories ADD SourceFormCandidateOrder int NULL;';
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

            migrationBuilder.Sql("""
                EXEC dbo.usp_SynchronizeFormsToPlays;

                IF NOT EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'UX_PlayAwardCategories_FormSourceSlot'
                )
                    CREATE UNIQUE NONCLUSTERED INDEX UX_PlayAwardCategories_FormSourceSlot
                        ON dbo.PlayAwardCategories
                           (PlayId, AwardCategoryCode, SourceFormCandidateOrder)
                        WHERE SourceFormCandidateOrder IS NOT NULL AND IsCurrent = 1;

                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains the additive source-slot identity,
            // index, synchronized candidates, images, and history.
        }
    }
}
