using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260827090000_V1_2_9_ScopePublishedUserIdentityByRole")]
public sealed class V1_2_9_ScopePublishedUserIdentityByRole : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
                RETURN;

            IF EXISTS
            (
                SELECT RoleCode, Username
                FROM dbo.Users
                WHERE IsPublished = 1
                GROUP BY RoleCode, Username
                HAVING COUNT_BIG(*) > 1
            )
                THROW 51049, 'Migration blocked: duplicate published Users RoleCode/Username values exist.', 1;

            IF EXISTS
            (
                SELECT RoleCode, Email
                FROM dbo.Users
                WHERE IsPublished = 1
                GROUP BY RoleCode, Email
                HAVING COUNT_BIG(*) > 1
            )
                THROW 51050, 'Migration blocked: duplicate published Users RoleCode/Email values exist.', 1;

            DECLARE @UsersObjectId int = OBJECT_ID(N'dbo.Users', N'U');
            DECLARE @DropLegacyIdentitySql nvarchar(max) = N'';

            SELECT @DropLegacyIdentitySql = @DropLegacyIdentitySql +
                CASE
                    WHEN indexInfo.is_unique_constraint = 1 THEN
                        N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(indexInfo.name) + N';'
                    ELSE
                        N'DROP INDEX ' + QUOTENAME(indexInfo.name) + N' ON dbo.Users;'
                END
            FROM sys.indexes AS indexInfo
            WHERE indexInfo.object_id = @UsersObjectId
              AND indexInfo.is_unique = 1
              AND indexInfo.is_primary_key = 0
              AND EXISTS
              (
                  SELECT 1
                  FROM sys.index_columns AS identityKey
                  INNER JOIN sys.columns AS identityColumn
                      ON identityColumn.object_id = identityKey.object_id
                     AND identityColumn.column_id = identityKey.column_id
                  WHERE identityKey.object_id = indexInfo.object_id
                    AND identityKey.index_id = indexInfo.index_id
                    AND identityKey.key_ordinal > 0
                    AND identityColumn.name IN (N'Username', N'Email')
              )
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM sys.index_columns AS roleKey
                  INNER JOIN sys.columns AS roleColumn
                      ON roleColumn.object_id = roleKey.object_id
                     AND roleColumn.column_id = roleKey.column_id
                  WHERE roleKey.object_id = indexInfo.object_id
                    AND roleKey.index_id = indexInfo.index_id
                    AND roleKey.key_ordinal > 0
                    AND roleColumn.name = N'RoleCode'
              );

            IF @DropLegacyIdentitySql <> N''
                EXEC sys.sp_executesql @DropLegacyIdentitySql;

            DECLARE @DropRoleScopedIdentitySql nvarchar(max) = N'';

            SELECT @DropRoleScopedIdentitySql = @DropRoleScopedIdentitySql +
                CASE
                    WHEN indexInfo.is_unique_constraint = 1 THEN
                        N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(indexInfo.name) + N';'
                    ELSE
                        N'DROP INDEX ' + QUOTENAME(indexInfo.name) + N' ON dbo.Users;'
                END
            FROM sys.indexes AS indexInfo
            WHERE indexInfo.object_id = @UsersObjectId
              AND indexInfo.name IN
                  (N'UX_Users_RoleCode_Username_Published', N'UX_Users_RoleCode_Email_Published');

            IF @DropRoleScopedIdentitySql <> N''
                EXEC sys.sp_executesql @DropRoleScopedIdentitySql;

            CREATE UNIQUE NONCLUSTERED INDEX UX_Users_RoleCode_Username_Published
                ON dbo.Users(RoleCode, Username)
                WHERE IsPublished = 1;

            CREATE UNIQUE NONCLUSTERED INDEX UX_Users_RoleCode_Email_Published
                ON dbo.Users(RoleCode, Email)
                WHERE IsPublished = 1;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Compatibility rollback intentionally retains role-scoped uniqueness.
        // Restoring global uniqueness would invalidate admin/jury pairs created
        // with the same username or e-mail address.
    }
}
