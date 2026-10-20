using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class JuryHomePageTableSettings_v_20261014130956 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            DropSettingsGuardsIfPresent(migrationBuilder);
            // Bootstrap precedes constraints. Existing IDs and administrator
            // choices are retained; only missing rows receive the true default.
            MigrationSqlResources.Execute(migrationBuilder,
                "JuryHomePageTableSettings_v_20261014130956.Seed.sql");

            migrationBuilder.CreateIndex(
                name: "UX_Configs_JuryHomePageTableName",
                schema: "dbo",
                table: "Configs",
                column: "ConfigName",
                unique: true,
                filter: "[ConfigName] IN ('HomePageJuryTableEnabled', 'HomePageMissionTableEnabled', 'HomePageMostWatchedTableEnabled', 'HomePageLeastWatchedTableEnabled')");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Configs_JuryHomePageTableValue",
                schema: "dbo",
                table: "Configs",
                sql: "NOT ([ConfigName] IN ('HomePageJuryTableEnabled', 'HomePageMissionTableEnabled', 'HomePageMostWatchedTableEnabled', 'HomePageLeastWatchedTableEnabled')) OR ([IsPublished] = 1 AND [ConfigValue] COLLATE Latin1_General_100_BIN2 IN ('true', 'false') AND DATALENGTH([ConfigValue]) = CASE WHEN [ConfigValue] COLLATE Latin1_General_100_BIN2 = 'true' THEN 8 ELSE 10 END)");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "JuryHomePageTableSettings_v_20261014130956", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Roll back behavior only. Never delete the four rows or reset
            // visibility choices when returning to/reapplying this version.
            DropSettingsGuardsIfPresent(migrationBuilder);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "JuryHomePageTableSettings_v_20261014130956", "Down.sql");
        }

        private static void DropSettingsGuardsIfPresent(MigrationBuilder migrationBuilder)
        {
            // A deployment can adopt a current schema with legacy EF history.
            // Reconcile just these guards, without modifying any Config data.
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'dbo.TR_Configs_ProtectJuryHomePageSettings', N'TR') IS NOT NULL
                    DROP TRIGGER dbo.TR_Configs_ProtectJuryHomePageSettings;
                IF EXISTS (SELECT 1 FROM sys.check_constraints
                           WHERE parent_object_id = OBJECT_ID(N'dbo.Configs')
                             AND name = N'CK_Configs_JuryHomePageTableValue')
                    ALTER TABLE dbo.Configs DROP CONSTRAINT CK_Configs_JuryHomePageTableValue;
                IF EXISTS (SELECT 1 FROM sys.indexes
                           WHERE object_id = OBJECT_ID(N'dbo.Configs')
                             AND name = N'UX_Configs_JuryHomePageTableName')
                    DROP INDEX UX_Configs_JuryHomePageTableName ON dbo.Configs;
                """);
        }
    }
}
