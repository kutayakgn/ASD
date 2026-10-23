using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class ScopedDatabaseWorkloads_v_20261023122512 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Legacy deployments may omit convention-only lookup indexes.
            migrationBuilder.Sql("DROP INDEX IF EXISTS [IX_Blacklist_PlayId] ON [dbo].[Blacklist];");
            migrationBuilder.Sql("""
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'IX_Form_SeasonAssignment_Season')
                BEGIN
                    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'IX_Form_SeasonId')
                        EXEC sys.sp_rename N'dbo.Form.IX_Form_SeasonId', N'IX_Form_SeasonAssignment_Season', N'INDEX';
                    ELSE
                        CREATE INDEX [IX_Form_SeasonAssignment_Season] ON dbo.Form(SeasonId);
                END;
                """);

            // Company schemas can already carry equivalent explicit lookups.
            // Startup validates their shape after applying all migrations.
            migrationBuilder.Sql("""
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Plays') AND name = N'IX_Plays_Slug')
                    CREATE INDEX [IX_Plays_Slug] ON dbo.Plays(Slug);
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Plays') AND name = N'IX_Plays_UnlinkedFormMatch')
                    CREATE INDEX [IX_Plays_UnlinkedFormMatch] ON dbo.Plays(SourceFormId)
                        INCLUDE (RecordType, PlayName, TheaterName) WHERE SourceFormId IS NULL;
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'IX_Form_SeasonAssignment_Date')
                    CREATE INDEX [IX_Form_SeasonAssignment_Date] ON dbo.Form(CreatedDate) INCLUDE (SeasonId);
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Blacklist') AND name = N'IX_Blacklist_PlayId_IsPublished')
                    CREATE INDEX [IX_Blacklist_PlayId_IsPublished] ON dbo.Blacklist(PlayId, IsPublished);
                """);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "ScopedDatabaseWorkloads_v_20261023122512", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Introduced in this version; remove before schema rollback.
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS [dbo].[TR_PlayAwardCategories_RefreshSeasonStatistics];");

            migrationBuilder.DropIndex(
                name: "IX_Plays_Slug",
                schema: "dbo",
                table: "Plays");

            migrationBuilder.DropIndex(
                name: "IX_Plays_UnlinkedFormMatch",
                schema: "dbo",
                table: "Plays");

            migrationBuilder.DropIndex(
                name: "IX_Form_SeasonAssignment_Date",
                schema: "dbo",
                table: "Form");

            migrationBuilder.DropIndex(
                name: "IX_Blacklist_PlayId_IsPublished",
                schema: "dbo",
                table: "Blacklist");

            migrationBuilder.Sql("""
                IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'IX_Form_SeasonAssignment_Season')
                BEGIN
                    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'IX_Form_SeasonId')
                        DROP INDEX [IX_Form_SeasonAssignment_Season] ON dbo.Form;
                    ELSE
                        EXEC sys.sp_rename N'dbo.Form.IX_Form_SeasonAssignment_Season', N'IX_Form_SeasonId', N'INDEX';
                END;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_Blacklist_PlayId",
                schema: "dbo",
                table: "Blacklist",
                column: "PlayId");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "ScopedDatabaseWorkloads_v_20261023122512", "Down.sql");
        }
    }
}
