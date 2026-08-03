using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

public partial class PreserveLegacyFormMapping : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            IF COL_LENGTH(N'dbo.Form', N'LegacyId') IS NULL
                ALTER TABLE dbo.Form ADD LegacyId int NULL;

            IF NOT EXISTS
            (
                SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID(N'dbo.Form')
                  AND name = N'UX_Form_LegacyId'
            )
                CREATE UNIQUE INDEX UX_Form_LegacyId ON dbo.Form(LegacyId)
                WHERE LegacyId IS NOT NULL;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Expand-only rollback: LegacyId preserves production lineage and is never removed.
    }
}