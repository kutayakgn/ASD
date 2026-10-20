using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class SimplifyMigrationFlow_v_20261014135212 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "SimplifyMigrationFlow_v_20261014135212", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "SimplifyMigrationFlow_v_20261014135212", "Down.sql");
        }
    }
}
