using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class RemoveObsoleteCandidateActiveRoleIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF EXISTS
                (
                    SELECT 1
                    FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
                      AND name = N'UX_PlayAwardCategories_Active_Play_Category_RoleCode'
                )
                    DROP INDEX [UX_PlayAwardCategories_Active_Play_Category_RoleCode]
                        ON [dbo].[PlayAwardCategories];
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // The obsolete index contradicts the current candidate-history contract
            // and must not be recreated by a compatibility rollback.
        }
    }
}