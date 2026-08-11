using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddJuryPresident : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF COL_LENGTH(N'dbo.Users', N'IsJuryPresident') IS NULL
                    ALTER TABLE dbo.Users ADD IsJuryPresident bit NOT NULL
                        CONSTRAINT DF_Users_IsJuryPresident DEFAULT (0) WITH VALUES;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            migrationBuilder.Sql("""
                IF NOT EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.Users')
                      AND name = N'UX_Users_OnePublishedJuryPresident'
                )
                    CREATE UNIQUE INDEX UX_Users_OnePublishedJuryPresident
                        ON dbo.Users(IsJuryPresident)
                        WHERE IsPublished = 1 AND IsJuryPresident = 1;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            migrationBuilder.Sql("""
                IF OBJECT_ID(N'dbo.CK_Users_JuryPresident', N'C') IS NULL
                    ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT CK_Users_JuryPresident
                        CHECK (IsJuryPresident = 0 OR (RoleCode = 2 AND IsActive = 1));
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback keeps the column and its data.
        }
    }
}
