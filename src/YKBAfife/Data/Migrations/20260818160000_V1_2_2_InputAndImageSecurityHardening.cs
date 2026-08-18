using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260818160000_V1_2_2_InputAndImageSecurityHardening")]
public sealed class V1_2_2_InputAndImageSecurityHardening : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Refreshes the Images trigger with extension, MIME and binary-signature
        // enforcement. Existing image bytes are preserved.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Security hardening is intentionally retained on compatibility rollback.
    }
}
