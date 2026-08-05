using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260805090000_EnsureCanonicalReferenceData")]
public sealed class EnsureCanonicalReferenceData : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Also repairs databases where an earlier baseline was recorded before
        // startup validation exposed a legacy-schema incompatibility.
        migrationBuilder.Sql("""
            EXEC sys.sp_set_session_context
                @key = N'AfifeBaselineAlreadyExists',
                @value = 1;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.Execute(migrationBuilder, "PrepareLegacyForm.sql", onlyWhenBaselineExists: true);
        MigrationSqlResources.ExecuteMissingTables(migrationBuilder, "InitialSchema.sql");
        MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
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

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Additive schema and reference contracts remain in place on rollback.
    }
}