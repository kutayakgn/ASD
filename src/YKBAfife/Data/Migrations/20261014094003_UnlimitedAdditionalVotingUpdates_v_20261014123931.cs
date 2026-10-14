using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class UnlimitedAdditionalVotingUpdates_v_20261014123931 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            DropExistingUsageIndexes(migrationBuilder);

            migrationBuilder.CreateIndex(
                name: "IX_AdditionalVotingUsages_Jury_Play",
                schema: "dbo",
                table: "AdditionalVotingUsages",
                columns: new[] { "AdditionalVotingId", "JuryId", "PlayId" },
                filter: "[IsPublished] = 1");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "UnlimitedAdditionalVotingUpdates_v_20261014123931", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            DropExistingUsageIndexes(migrationBuilder);

            migrationBuilder.CreateIndex(
                name: "UX_AdditionalVotingUsages_OneTime",
                schema: "dbo",
                table: "AdditionalVotingUsages",
                columns: new[] { "AdditionalVotingId", "JuryId", "PlayId" },
                // Retain every usage event created under the unlimited rule.
                // Restoring the old unique constraint would fail after a second
                // event or require deleting audit history. The old name is kept
                // for older application catalog checks; jury code controls its
                // historical one-use behavior when that version is deployed.
                filter: "[IsPublished] = 1");
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "UnlimitedAdditionalVotingUpdates_v_20261014123931", "Down.sql");
        }

        private static void DropExistingUsageIndexes(MigrationBuilder migrationBuilder)
        {
            // A company database can already contain the new index while its
            // migration history still points to an older deployment. Reconcile
            // only these two index definitions; all usage rows remain intact.
            migrationBuilder.Sql("""
                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages')
                      AND name = N'UX_AdditionalVotingUsages_OneTime'
                )
                    DROP INDEX [UX_AdditionalVotingUsages_OneTime]
                        ON dbo.AdditionalVotingUsages;

                IF EXISTS
                (
                    SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages')
                      AND name = N'IX_AdditionalVotingUsages_Jury_Play'
                )
                    DROP INDEX [IX_AdditionalVotingUsages_Jury_Play]
                        ON dbo.AdditionalVotingUsages;
                """);
        }
    }
}
