using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class GroupDeletionRules_v_20261027114234 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "GroupDeletionRules_v_20261027114234", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "GroupDeletionRules_v_20261027114234", "Down.sql");
        }
    }
}
