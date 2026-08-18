using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260819100000_V1_2_4_CorrectCandidateUniquenessContract")]
public sealed class V1_2_4_CorrectCandidateUniquenessContract : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        MigrationSqlResources.EnsureCandidateUniquenessContract(migrationBuilder);
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // The rejected unique index contradicts the candidate identity contract
        // and must not be restored by a compatibility rollback.
    }
}
