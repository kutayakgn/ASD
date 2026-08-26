using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260819150000_V1_2_7_EnforceUsernameAndSynchronizePlaySlug")]
public sealed class V1_2_7_EnforceUsernameAndSynchronizePlaySlug : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            IF OBJECT_ID(N'dbo.Users', N'U') IS NOT NULL
               AND OBJECT_ID(N'dbo.CK_Users_Username_InstagramFormat', N'C') IS NULL
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.Users
                    WHERE LEN([Username]) NOT BETWEEN 3 AND 30
                       OR DATALENGTH([Username]) <> LEN([Username]) * 2
                       OR [Username] COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9._]%'
                )
                    ALTER TABLE dbo.Users WITH CHECK
                        ADD CONSTRAINT CK_Users_Username_InstagramFormat CHECK
                        (
                            LEN([Username]) BETWEEN 3 AND 30
                            AND DATALENGTH([Username]) = LEN([Username]) * 2
                            AND [Username] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Za-z0-9._]%'
                        );
                ELSE
                    -- Existing accounts are preserved. Legacy invalid values remain readable,
                    -- while every new insert/update is checked from this point onward.
                    ALTER TABLE dbo.Users WITH NOCHECK
                        ADD CONSTRAINT CK_Users_Username_InstagramFormat CHECK
                        (
                            LEN([Username]) BETWEEN 3 AND 30
                            AND DATALENGTH([Username]) = LEN([Username]) * 2
                            AND [Username] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Za-z0-9._]%'
                        );

                ALTER TABLE dbo.Users CHECK CONSTRAINT CK_Users_Username_InstagramFormat;
            END;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Data-loss-free rollback: keep the validation constraint and slug synchronization.
    }
}
