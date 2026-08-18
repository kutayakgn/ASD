using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260819110000_V1_2_5_DefaultFormCreatedPlayStatusesDisabled")]
public sealed class V1_2_5_DefaultFormCreatedPlayStatusesDisabled : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Refreshes usp_SynchronizeFormsToPlays so newly materialized Plays start
        // outside both admin-controlled lists. Existing Play values are preserved.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Existing admin choices and synchronized records must not be rewritten.
    }
}
