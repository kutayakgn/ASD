using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class RespectInactiveFormsForDirectorCandidates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                /* Company databases can contain published votes attached to a
                   director of an already inactive Form. Normalize the complete
                   dependency chain in lifecycle context so maintenance updates
                   are not mistaken for new visible relationships. */
                EXEC sys.sp_set_session_context
                    @key = N'FormLifecycleSyncInProgress', @value = 1;

                BEGIN TRY
                    UPDATE vote
                    SET IsPublished = 0,
                        IsActive = 0,
                        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                    FROM dbo.JuryVotes AS vote
                    INNER JOIN dbo.PlayAwardCategories AS candidate
                        ON candidate.Id = vote.PlayAwardCategoryId
                    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                    WHERE candidate.AwardCategoryCode = 1002
                      AND (vote.IsPublished = 1 OR vote.IsActive = 1)
                      AND
                      (
                          formRecord.IsPublished = 0
                          OR formRecord.IsActive = 0
                          OR play.IsPublished = 0
                          OR play.IsActive = 0
                      );

                    UPDATE candidate
                    SET IsPublished = 0,
                        IsActive = 0,
                        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                    FROM dbo.PlayAwardCategories AS candidate
                    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                    WHERE candidate.AwardCategoryCode = 1002
                      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1)
                      AND
                      (
                          formRecord.IsPublished = 0
                          OR formRecord.IsActive = 0
                          OR play.IsPublished = 0
                          OR play.IsActive = 0
                      );

                    /* Only effective source plays may have their mandatory
                       director candidate activated. */
                    UPDATE candidate
                    SET IsActive = 1,
                        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
                    FROM dbo.PlayAwardCategories AS candidate
                    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
                    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
                    WHERE candidate.AwardCategoryCode = 1002
                      AND candidate.IsPublished = 1
                      AND candidate.IsActive = 0
                      AND play.IsPublished = 1
                      AND play.IsActive = 1
                      AND
                      (
                          play.SourceFormId IS NULL
                          OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
                      );

                    EXEC sys.sp_set_session_context
                        @key = N'FormLifecycleSyncInProgress', @value = NULL;
                END TRY
                BEGIN CATCH
                    EXEC sys.sp_set_session_context
                        @key = N'FormLifecycleSyncInProgress', @value = NULL;
                    THROW;
                END CATCH;

                EXEC dbo.usp_RefreshRankings;
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains repaired soft-delete state and does
            // not reactivate candidates belonging to inactive Form sources.
        }
    }
}
