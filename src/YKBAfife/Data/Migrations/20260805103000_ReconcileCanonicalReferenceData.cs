using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260805103000_ReconcileCanonicalReferenceData")]
public sealed class ReconcileCanonicalReferenceData : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Canonical integration rows must remain available in every environment.
    }
}
