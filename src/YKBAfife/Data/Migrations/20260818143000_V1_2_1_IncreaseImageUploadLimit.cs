using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260818143000_V1_2_1_IncreaseImageUploadLimit")]
public sealed class V1_2_1_IncreaseImageUploadLimit : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Refreshes Form image decoding and installs the table-wide 50 MB guard.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Existing images are retained during compatibility rollback.
    }
}
