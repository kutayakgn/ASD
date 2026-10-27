using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class DuplicateGroupCascadeCompatibility_v_20261027142314 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "DuplicateGroupCascadeCompatibility_v_20261027142314", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "DuplicateGroupCascadeCompatibility_v_20261027142314", "Down.sql");
        }
    }
}
