using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260817103000_V1_1_1_NormalizeJuryLogDefaults")]
public sealed class V1_1_1_NormalizeJuryLogDefaults : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            IF OBJECT_ID(N'dbo.JuryLogs', N'U') IS NULL
                RETURN;

            DECLARE @ColumnName sysname;
            DECLARE @ConstraintName sysname;
            DECLARE @DropSql nvarchar(max);

            DECLARE default_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT columnInfo.name, defaultInfo.name
            FROM sys.default_constraints AS defaultInfo
            INNER JOIN sys.columns AS columnInfo
                ON columnInfo.object_id = defaultInfo.parent_object_id
               AND columnInfo.column_id = defaultInfo.parent_column_id
            WHERE defaultInfo.parent_object_id = OBJECT_ID(N'dbo.JuryLogs')
              AND columnInfo.name IN
              (
                  N'Id', N'CorrelationId', N'IsAdditionalVoting',
                  N'AffectedVoteCount', N'OccurredAt', N'Application',
                  N'Source', N'IsSuccessful', N'IsPublished'
              );

            OPEN default_cursor;
            FETCH NEXT FROM default_cursor INTO @ColumnName, @ConstraintName;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @DropSql =
                    N'ALTER TABLE dbo.JuryLogs DROP CONSTRAINT ' +
                    QUOTENAME(@ConstraintName) + N';';
                EXEC sys.sp_executesql @DropSql;

                FETCH NEXT FROM default_cursor INTO @ColumnName, @ConstraintName;
            END;

            CLOSE default_cursor;
            DEALLOCATE default_cursor;

            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_Id
                    DEFAULT (newsequentialid()) FOR Id;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_CorrelationId
                    DEFAULT (newid()) FOR CorrelationId;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_IsAdditionalVoting
                    DEFAULT ((0)) FOR IsAdditionalVoting;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_AffectedVoteCount
                    DEFAULT ((0)) FOR AffectedVoteCount;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_OccurredAt
                    DEFAULT (DATEADD(HOUR, (3), SYSUTCDATETIME())) FOR OccurredAt;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_Application
                    DEFAULT (N'AfifeJury') FOR Application;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_Source
                    DEFAULT (N'JuryPanel') FOR Source;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_IsSuccessful
                    DEFAULT ((0)) FOR IsSuccessful;
            ALTER TABLE dbo.JuryLogs
                ADD CONSTRAINT DF_JuryLogs_IsPublished
                    DEFAULT ((1)) FOR IsPublished;
            """)
            .Annotation(
                MigrationSqlResources.ReviewedDataSafeSqlAnnotation,
                true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // İsim normalizasyonu veri kaybı olmadan geri alınamaz ve gerekli değildir.
    }
}
