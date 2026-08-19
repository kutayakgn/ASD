using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260819113000_V1_2_6_RepairFormSourceSlotContract")]
public sealed class V1_2_6_RepairFormSourceSlotContract : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        MigrationSqlResources.EnsureCandidateUniquenessContract(migrationBuilder);
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // The removed unique slot index can reject otherwise valid candidate
        // combinations and must not be restored on compatibility rollback.
    }
}
