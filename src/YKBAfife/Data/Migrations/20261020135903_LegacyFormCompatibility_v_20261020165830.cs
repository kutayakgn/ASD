using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class LegacyFormCompatibility_v_20261020165830 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "TheaterName",
                schema: "dbo",
                table: "Plays",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(255)",
                oldMaxLength: 255);

            migrationBuilder.AlterColumn<string>(
                name: "PlayName",
                schema: "dbo",
                table: "Plays",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(255)",
                oldMaxLength: 255);

            migrationBuilder.AlterColumn<string>(
                name: "Candidate",
                schema: "dbo",
                table: "PlayAwardCategories",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(250)",
                oldMaxLength: 250);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "LegacyFormCompatibility_v_20261020165830", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Keep the expanded storage: legacy Form names can exceed the old
            // limits and must remain intact when application behavior rolls back.
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "LegacyFormCompatibility_v_20261020165830", "Down.sql");
        }
    }
}
