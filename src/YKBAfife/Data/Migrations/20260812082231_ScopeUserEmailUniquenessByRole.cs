using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class ScopeUserEmailUniquenessByRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF EXISTS
                (
                    SELECT RoleCode, Email
                    FROM dbo.Users
                    WHERE IsPublished = 1
                    GROUP BY RoleCode, Email
                    HAVING COUNT(*) > 1
                )
                    THROW 51043, 'Migration blocked: duplicate published Users RoleCode/Email values exist.', 1;

                DECLARE @UsersObjectId int = OBJECT_ID(N'dbo.Users');
                DECLARE @DropGlobalEmailUniquenessSql nvarchar(max) = N'';

                SELECT @DropGlobalEmailUniquenessSql =
                    @DropGlobalEmailUniquenessSql +
                    CASE
                        WHEN indexInfo.is_unique_constraint = 1 THEN
                            N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(indexInfo.name) + N';'
                        ELSE
                            N'DROP INDEX ' + QUOTENAME(indexInfo.name) + N' ON dbo.Users;'
                    END
                FROM sys.indexes AS indexInfo
                WHERE indexInfo.object_id = @UsersObjectId
                  AND indexInfo.is_unique = 1
                  AND
                  (
                      SELECT COUNT(*)
                      FROM sys.index_columns AS keyColumn
                      WHERE keyColumn.object_id = indexInfo.object_id
                        AND keyColumn.index_id = indexInfo.index_id
                        AND keyColumn.key_ordinal > 0
                  ) = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM sys.index_columns AS keyColumn
                      INNER JOIN sys.columns AS columnInfo
                          ON columnInfo.object_id = keyColumn.object_id
                         AND columnInfo.column_id = keyColumn.column_id
                      WHERE keyColumn.object_id = indexInfo.object_id
                        AND keyColumn.index_id = indexInfo.index_id
                        AND keyColumn.key_ordinal = 1
                        AND columnInfo.name = N'Email'
                  );

                IF @DropGlobalEmailUniquenessSql <> N''
                    EXEC sys.sp_executesql @DropGlobalEmailUniquenessSql;

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM sys.indexes
                    WHERE object_id = @UsersObjectId
                      AND name = N'UX_Users_RoleCode_Email_Published'
                )
                    CREATE UNIQUE NONCLUSTERED INDEX UX_Users_RoleCode_Email_Published
                        ON dbo.Users(RoleCode, Email)
                        WHERE IsPublished = 1;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains role-scoped e-mail uniqueness. Restoring
            // global e-mail uniqueness would reject the newly valid admin/jury pairs.
        }
    }
}
