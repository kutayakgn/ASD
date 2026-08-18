using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260818173000_V1_2_3_IncreaseImageUploadLimitTo150Mb")]
public sealed class V1_2_3_IncreaseImageUploadLimitTo150Mb : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Reinstalls the synchronization procedures and Images trigger with the
        // 150 MB per-image limit. Existing image data is preserved.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // The higher non-destructive limit remains in place on compatibility rollback.
    }
}
