using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialManagedBaseline : Migration
    {
        /// <inheritdoc />
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
                    CASE WHEN OBJECT_ID(N'dbo.Users', N'U') IS NOT NULL THEN 1 ELSE 0 END;
                EXEC sys.sp_set_session_context
                    @key = N'AfifeBaselineAlreadyExists',
                    @value = @baselineExists;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            // Existing databases keep every row and schema object. Empty databases
            // are provisioned from the reviewed, canonical SQL Server schema.
            MigrationSqlResources.Execute(migrationBuilder, "InitialSchema.sql", skipWhenBaselineExists: true);
            MigrationSqlResources.ExecuteMissingTables(migrationBuilder, "InitialSchema.sql");
            MigrationSqlResources.Execute(migrationBuilder, "LegacyUpgrade.sql", onlyWhenBaselineExists: true);
            MigrationSqlResources.ExecuteMissingSchemaObjects(migrationBuilder, "InitialSchema.sql");

            migrationBuilder.Sql("""
                EXEC sys.sp_set_session_context
                    @key = N'AfifeBaselineAlreadyExists',
                    @value = NULL;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
            MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");

            migrationBuilder.Sql("""
                EXEC dbo.usp_ReassignFormSeasons;
                EXEC dbo.usp_SynchronizeFormsToPlays;
                EXEC dbo.usp_RefreshSeasonStatistics;
                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Additive-only rollback: never drop tables, columns, constraints, or data.
        }
    }
}
