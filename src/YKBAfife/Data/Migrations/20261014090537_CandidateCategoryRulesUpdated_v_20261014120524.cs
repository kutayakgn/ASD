using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class CandidateCategoryRulesUpdated_v_20261014120524 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "CandidateCategoryRulesUpdated_v_20261014120524", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "CandidateCategoryRulesUpdated_v_20261014120524", "Down.sql");
        }
    }
}
