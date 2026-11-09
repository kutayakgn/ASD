using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class UserBirthDate_v_20261109103351 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Company-style history adoption can retain this nullable column and its values.
            migrationBuilder.AddColumn<DateOnly>(
                name: "BirthDate",
                schema: "dbo",
                table: "Users",
                type: "date",
                nullable: true)
                .Annotation(NoDataLossSqlServerMigrationsSqlGenerator.PreserveExistingColumnAnnotation, true);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "UserBirthDate_v_20261109103351", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BirthDate",
                schema: "dbo",
                table: "Users");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "UserBirthDate_v_20261109103351", "Down.sql");
        }
    }
}
