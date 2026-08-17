using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class V1_0_1_RemoveYoungGenerationCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            MigrationSqlResources.Execute(migrationBuilder, "ReferenceData.sql");
            MigrationSqlResources.Execute(migrationBuilder, "Programmability.sql");

            migrationBuilder.Sql("""
                DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
                DECLARE @RetiredImageIds TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);

                INSERT INTO @RetiredImageIds (Id)
                SELECT DISTINCT PhotoImageId
                FROM dbo.PlayAwardCategories
                WHERE AwardCategoryCode = 1012
                  AND PhotoImageId IS NOT NULL;

                EXEC sys.sp_set_session_context
                    @key = N'FormLifecycleSyncInProgress', @value = 1;

                BEGIN TRY
                    UPDATE vote
                    SET IsPublished = 0,
                        IsActive = 0,
                        UpdatedAt = @Now
                    FROM dbo.JuryVotes AS vote
                    INNER JOIN dbo.PlayAwardCategories AS candidate
                        ON candidate.Id = vote.PlayAwardCategoryId
                    WHERE candidate.AwardCategoryCode = 1012
                      AND (vote.IsPublished = 1 OR vote.IsActive = 1);

                    UPDATE candidate
                    SET IsPublished = 0,
                        IsActive = 0,
                        IsCurrent = 0,
                        UpdatedAt = @Now
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.AwardCategoryCode = 1012
                      AND
                      (
                          candidate.IsPublished = 1
                          OR candidate.IsActive = 1
                          OR candidate.IsCurrent = 1
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

                UPDATE image
                SET IsPublished = 0,
                    UpdatedAt = @Now
                FROM dbo.Images AS image
                INNER JOIN @RetiredImageIds AS retired ON retired.Id = image.Id
                WHERE image.IsPublished = 1
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM dbo.PlayAwardCategories AS candidate
                      WHERE candidate.PhotoImageId = image.Id
                        AND candidate.IsPublished = 1
                  )
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM dbo.Users AS appUser
                      WHERE appUser.PhotoImageId = image.Id
                        AND appUser.IsPublished = 1
                  )
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM dbo.Announcements AS announcement
                      WHERE (announcement.ImageId = image.Id
                             OR announcement.BackgroundImageId = image.Id)
                        AND announcement.IsPublished = 1
                  );
                """)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Compatibility rollback retains the retired category and all related
            // candidate/vote/ranking/image history in its unpublished state.
        }
    }
}
