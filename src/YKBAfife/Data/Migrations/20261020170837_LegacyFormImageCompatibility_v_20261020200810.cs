using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class LegacyFormImageCompatibility_v_20261020200810 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Update routine definitions only; keep stored Form/image data intact.
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "LegacyFormImageCompatibility_v_20261020200810", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "LegacyFormImageCompatibility_v_20261020200810", "Down.sql");
        }
    }
}
