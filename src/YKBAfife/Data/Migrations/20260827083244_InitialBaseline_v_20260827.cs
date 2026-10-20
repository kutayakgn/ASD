using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

/// <summary>
/// Data-preserving convergence baseline for empty, legacy/partial and current databases.
/// The EF designer and snapshot contain the complete canonical relational model; this
/// migration deliberately uses reviewed idempotent SQL to adopt existing installations.
/// </summary>
public partial class InitialBaseline_v_20260827 : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            SET ANSI_NULLS ON;
            SET QUOTED_IDENTIFIER ON;
            SET ANSI_PADDING ON;
            SET ANSI_WARNINGS ON;
            SET ARITHABORT ON;
            SET CONCAT_NULL_YIELDS_NULL ON;
            SET NUMERIC_ROUNDABORT OFF;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        migrationBuilder.Sql("""
            DECLARE @baselineExists sql_variant =
                CASE WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.tables AS t
                    INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
                    WHERE s.name = N'dbo'
                      AND t.name IN
                      (
                          N'Form', N'Users', N'Plays', N'AwardCategories',
                          N'PlayAwardCategories', N'JuryVotes', N'Roles',
                          N'PlayStatuses', N'Announcements', N'Images'
                      )
                ) THEN 1 ELSE 0 END;

            EXEC sys.sp_set_session_context
                @key = N'AfifeBaselineAlreadyExists',
                @value = @baselineExists;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.Execute(
            migrationBuilder,
            "InitialSchema.sql",
            skipWhenBaselineExists: true);
        MigrationSqlResources.ExecuteLegacyBaselineUpgrade(migrationBuilder);

        migrationBuilder.Sql("""
            EXEC sys.sp_set_session_context
                @key = N'AfifeBaselineAlreadyExists',
                @value = NULL;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.ExecuteVersionedDatabaseObjects(
            migrationBuilder,
            "InitialBaseline_v_20260827",
            "Up.sql");
        // Old Form rows are synchronized in this migration, before later
        // migrations run. Apply the frozen compatibility fix before that first
        // projection without changing the historical SQL packages.
        MigrationSqlResources.Execute(migrationBuilder,
            "LegacyFormProjectionCompatibility.sql");
        // The first synchronization can import legacy photo URLs that do not
        // match the detected binary type, or retire a legacy reference image.
        MigrationSqlResources.Execute(migrationBuilder,
            "LegacyFormImageCompatibility.sql");
        MigrationSqlResources.Execute(migrationBuilder, "BaselineDataRepairs.sql");

        migrationBuilder.Sql("""
            EXEC dbo.usp_ReassignFormSeasons;
            EXEC dbo.usp_SynchronizeFormsToPlays;
            EXEC dbo.usp_RefreshSeasonStatistics;
            EXEC dbo.usp_RefreshRankings;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.AdoptSquashedBaseline(migrationBuilder);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Never drop an application database during rollback.
    }
}
