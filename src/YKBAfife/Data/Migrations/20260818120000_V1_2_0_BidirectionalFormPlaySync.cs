using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260818120000_V1_2_0_BidirectionalFormPlaySync")]
public sealed class V1_2_0_BidirectionalFormPlaySync : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // CREATE OR ALTER keeps this deploy safe for both legacy-upgraded and
        // already managed databases. Prerequisites are applied automatically.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");
        MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");

        // The old unique current-role index incorrectly rejects two different
        // candidates sharing a RoleCode. The four-field candidate index remains
        // the authoritative uniqueness rule.
        MigrationSqlResources.EnsureCandidateUniquenessContract(migrationBuilder);

        // Re-read existing Form payloads once so photos which were previously
        // lost by JSON_VALUE's 4000-character limit are materialized in Images.
        migrationBuilder.Sql(
            """
            IF OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays', N'P') IS NOT NULL
               AND OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
               AND OBJECT_ID(N'dbo.Plays', N'U') IS NOT NULL
               AND OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
               AND OBJECT_ID(N'dbo.Images', N'U') IS NOT NULL
            BEGIN
                EXEC sys.sp_set_session_context
                    @key = N'AdminOperationName',
                    @value = N'V1.2.0 Form/Play/Aday Görsel Senkronizasyonu';
                BEGIN TRY
                    EXEC dbo.usp_SynchronizeFormsToPlays;
                    EXEC sys.sp_set_session_context
                        @key = N'AdminOperationName', @value = NULL;
                END TRY
                BEGIN CATCH
                    EXEC sys.sp_set_session_context
                        @key = N'AdminOperationName', @value = NULL;
                    THROW;
                END CATCH;
            END;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Data synchronized between the three projections must not be discarded.
        // Rolling back the application version is safe; programmable objects are
        // refreshed by the migration set belonging to that version.
    }
}
