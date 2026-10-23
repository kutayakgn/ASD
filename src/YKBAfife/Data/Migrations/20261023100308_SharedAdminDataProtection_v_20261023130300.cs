using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class SharedAdminDataProtection_v_20261023130300 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Down retains this secret table. Reapplying must restore that exact
            // table (and its key IDs/XML), never replace it with an empty ring.
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'dbo.SharedAdminDataProtectionKeys', N'U') IS NULL
                BEGIN
                    DECLARE @RetainedKeyTable sysname;
                    DECLARE @RetainedKeyTableCount int;
                    SELECT @RetainedKeyTableCount = COUNT(*), @RetainedKeyTable = MIN(t.name)
                    FROM sys.tables t
                    LEFT JOIN sys.extended_properties p ON p.class = 1 AND p.major_id = t.object_id
                        AND p.minor_id = 0 AND p.name = N'Afife:ArchivedTableSource'
                    WHERE t.schema_id = SCHEMA_ID(N'dbo')
                      AND (CONVERT(nvarchar(128), p.value) = N'SharedAdminDataProtectionKeys'
                           OR t.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\');
                    IF @RetainedKeyTableCount > 1
                        THROW 52751, N'Multiple retained admin key stores exist; automatic replacement is forbidden.', 1;
                    IF @RetainedKeyTableCount = 1
                    BEGIN
                        DECLARE @RetainedKeyObject nvarchar(517) = N'dbo.' + QUOTENAME(@RetainedKeyTable);
                        EXEC sys.sp_rename @RetainedKeyObject, N'SharedAdminDataProtectionKeys', N'OBJECT';
                        IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 1
                            AND major_id = OBJECT_ID(N'dbo.SharedAdminDataProtectionKeys') AND minor_id = 0
                            AND name = N'Afife:ArchivedTableSource')
                            EXEC sys.sp_dropextendedproperty @name = N'Afife:ArchivedTableSource',
                                @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE',
                                @level1name = N'SharedAdminDataProtectionKeys';
                        IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE class = 1
                            AND major_id = OBJECT_ID(N'dbo.SharedAdminDataProtectionKeys') AND minor_id = 0
                            AND name = N'Afife:ArchivedTableAt')
                            EXEC sys.sp_dropextendedproperty @name = N'Afife:ArchivedTableAt',
                                @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE',
                                @level1name = N'SharedAdminDataProtectionKeys';
                    END
                    ELSE
                        CREATE TABLE dbo.SharedAdminDataProtectionKeys
                        (
                            Id uniqueidentifier NOT NULL DEFAULT newsequentialid(),
                            FriendlyName nvarchar(255) NULL,
                            [Xml] nvarchar(max) NOT NULL,
                            CreatedAtUtc datetime2 NOT NULL DEFAULT sysutcdatetime(),
                            IsPublished bit NOT NULL DEFAULT CAST(1 AS bit),
                            CONSTRAINT PK_SharedAdminDataProtectionKeys PRIMARY KEY (Id),
                            CONSTRAINT CK_SharedAdminDataProtectionKeys_Published CHECK (IsPublished = 1)
                        );
                END;
                """);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "SharedAdminDataProtection_v_20261023130300", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Introduced in this version; remove before schema rollback.
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS [dbo].[TR_SharedAdminDataProtectionKeys_AppendOnly];");

            migrationBuilder.DropTable(
                name: "SharedAdminDataProtectionKeys",
                schema: "dbo");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "SharedAdminDataProtection_v_20261023130300", "Down.sql");
            // Prior audit installers do not recognize this secret metadata. The
            // retained archive must not acquire a full-row XML audit on rollback.
            migrationBuilder.Sql("""
                DECLARE @RemoveKeyAuditSql nvarchar(max) =
                (
                    SELECT STRING_AGG(CONVERT(nvarchar(max), N'DROP TRIGGER '
                        + QUOTENAME(s.name) + N'.' + QUOTENAME(tr.name) + N';'), NCHAR(10))
                    FROM sys.triggers tr
                    INNER JOIN sys.tables t ON t.object_id = tr.parent_id
                    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                    WHERE s.name = N'dbo'
                      AND (t.name = N'SharedAdminDataProtectionKeys'
                           OR t.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\')
                      AND tr.name LIKE N'TR\_AdminAudit\_%' ESCAPE N'\'
                );
                IF @RemoveKeyAuditSql IS NOT NULL EXEC sys.sp_executesql @RemoveKeyAuditSql;
                """);
        }
    }
}
