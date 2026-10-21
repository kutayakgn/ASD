using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class ScopedFormSynchronization_v_20261021181057 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Replace routine definitions; do not replay a full historical sync.
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "ScopedFormSynchronization_v_20261021181057", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Restore the prior routines without removing stored Form data.
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "ScopedFormSynchronization_v_20261021181057", "Down.sql");
        }
    }
}
