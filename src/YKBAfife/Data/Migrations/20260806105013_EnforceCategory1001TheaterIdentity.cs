using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

public partial class EnforceCategory1001TheaterIdentity : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Install the new invariant first so every concurrent write observes it.
        MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

        migrationBuilder.Sql("""
            /* Existing company databases can contain a published 1001 row whose
               source Form was deactivated before the lifecycle guards existed.
               This migration installs those guards above, so repair the legacy
               visibility in the same lifecycle synchronization context before
               updating the system-managed candidate identity. Always clear the
               session value because SESSION_CONTEXT is not transaction-scoped. */
            EXEC sys.sp_set_session_context
                @key = N'FormLifecycleSyncInProgress', @value = 1;

            BEGIN TRY
                UPDATE candidate
                SET
                    candidate.Candidate = play.TheaterName,
                    candidate.Role = N'Tiyatro',
                    candidate.IsPublished = CASE
                        WHEN play.SourceFormId IS NOT NULL
                         AND
                         (
                             play.IsActive = 0
                             OR formRecord.IsPublished = 0
                             OR formRecord.IsActive = 0
                         ) THEN 0 ELSE candidate.IsPublished END,
                    candidate.IsActive = CASE
                        WHEN play.SourceFormId IS NOT NULL
                         AND
                         (
                             play.IsActive = 0
                             OR formRecord.IsPublished = 0
                             OR formRecord.IsActive = 0
                         ) THEN 0 ELSE candidate.IsActive END,
                    candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                FROM dbo.PlayAwardCategories AS candidate
                INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                WHERE candidate.AwardCategoryCode = 1001
                  AND play.RecordType = 0
                  AND
                  (
                      candidate.Candidate <> play.TheaterName
                      OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
                      OR
                      (
                          play.SourceFormId IS NOT NULL
                          AND
                          (
                              play.IsActive = 0
                              OR formRecord.IsPublished = 0
                              OR formRecord.IsActive = 0
                          )
                          AND (candidate.IsPublished = 1 OR candidate.IsActive = 1)
                      )
                  );

                EXEC sys.sp_set_session_context
                    @key = N'FormLifecycleSyncInProgress', @value = NULL;
            END TRY
            BEGIN CATCH
                EXEC sys.sp_set_session_context
                    @key = N'FormLifecycleSyncInProgress', @value = NULL;
                THROW;
            END CATCH;
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Canonical candidate/role values are retained by compatibility rollback.
    }
}
