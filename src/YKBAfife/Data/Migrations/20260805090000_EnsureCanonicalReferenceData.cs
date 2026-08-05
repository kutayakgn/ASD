using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260805090000_EnsureCanonicalReferenceData")]
public sealed class EnsureCanonicalReferenceData : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Reference contracts are immutable and must never be deleted on rollback.
    }
}
