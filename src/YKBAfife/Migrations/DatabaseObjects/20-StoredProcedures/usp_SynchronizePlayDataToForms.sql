/*
    Keeps the editable admin projection and its source Form in sync.  The Form
    remains the import contract, while edits made through Plays or
    PlayAwardCategories are written back so a later Form synchronization cannot
    restore stale names or photos.
*/
CREATE OR ALTER PROCEDURE dbo.usp_SynchronizePlayDataToForms
    @PlayId uniqueidentifier = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    EXEC sys.sp_set_session_context
        @key = N'PlayToFormSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* Admin-created candidates also need a stable Form array slot. */
        ;WITH MissingSlots AS
        (
            SELECT
                candidate.Id,
                COALESCE
                (
                    (
                        SELECT MAX(existing.SourceFormCandidateOrder)
                        FROM dbo.PlayAwardCategories AS existing
                        WHERE existing.PlayId = candidate.PlayId
                          AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                    ),
                    0
                ) +
                ROW_NUMBER() OVER
                (
                    PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                    ORDER BY candidate.CreatedAt, candidate.RoleCode, candidate.Id
                ) AS NewSourceOrder
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE play.SourceFormId IS NOT NULL
              AND (@PlayId IS NULL OR play.Id = @PlayId)
              AND candidate.AwardCategoryCode BETWEEN 1003 AND 1011
              AND candidate.SourceFormCandidateOrder IS NULL
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
        )
        UPDATE candidate
        SET SourceFormCandidateOrder = missing.NewSourceOrder,
            UpdatedAt = COALESCE(candidate.UpdatedAt, @Now)
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN MissingSlots AS missing ON missing.Id = candidate.Id;

        CREATE TABLE #CandidatePayload
        (
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL,
            CandidateJson nvarchar(max) NOT NULL,
            PRIMARY KEY (PlayId, AwardCategoryCode)
        );

        INSERT INTO #CandidatePayload (PlayId, AwardCategoryCode, CandidateJson)
        SELECT play.Id,
               category.AwardCategoryCode,
               JSON_QUERY
               (
                   COALESCE
                   (
                       (
                           SELECT
                               candidate.Candidate AS [Name],
                               candidate.Role AS [Role],
                               candidateImage.FileName AS [ImageUrl],
                               /* FOR JSON serializes varbinary(max) as Base64. */
                               candidateImage.ImageData AS [Base64]
                           FROM dbo.PlayAwardCategories AS candidate
                           LEFT JOIN dbo.Images AS candidateImage
                               ON candidateImage.Id = candidate.PhotoImageId
                              AND candidateImage.IsPublished = 1
                           WHERE candidate.PlayId = play.Id
                             AND candidate.AwardCategoryCode = category.AwardCategoryCode
                             AND candidate.IsPublished = 1
                             AND candidate.IsCurrent = 1
                           ORDER BY
                               COALESCE(candidate.SourceFormCandidateOrder, 2147483647),
                               candidate.RoleCode,
                               candidate.CreatedAt,
                               candidate.Id
                           FOR JSON PATH
                       ),
                       N'[]'
                   )
               )
        FROM dbo.Plays AS play
        CROSS JOIN
        (
            VALUES (1003), (1004), (1005), (1006), (1007),
                   (1008), (1009), (1010), (1011)
        ) AS category(AwardCategoryCode)
        WHERE play.SourceFormId IS NOT NULL
          AND (@PlayId IS NULL OR play.Id = @PlayId);

        UPDATE formRecord
        SET
            RepertoireName = play.PlayName,
            TheatreName = play.TheaterName,
            Phone = COALESCE(play.Phone, formRecord.Phone),
            ContactName = play.ContactPersonName,
            ContactPhone = play.ContactPersonPhone,
            Email = COALESCE(play.Email, formRecord.Email),
            Director = COALESCE(director.Candidate, formRecord.Director),
            LeadActress = actress.CandidateJson,
            LeadActor = actor.CandidateJson,
            SupportActress = supportActress.CandidateJson,
            SupportActor = supportActor.CandidateJson,
            StageDesign = stageDesign.CandidateJson,
            ClothesDesign = clothesDesign.CandidateJson,
            StageMusic = stageMusic.CandidateJson,
            LightDesign = lightDesign.CandidateJson,
            Choreography = choreography.CandidateJson,
            IsActive = play.IsActive,
            IsPublished = play.IsPublished,
            UpdatedDate = @Now
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        OUTER APPLY
        (
            SELECT TOP (1) candidate.Candidate
            FROM dbo.PlayAwardCategories AS candidate
            WHERE candidate.PlayId = play.Id
              AND candidate.AwardCategoryCode = 1002
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
            ORDER BY COALESCE(candidate.SourceFormCandidateOrder, 0), candidate.Id
        ) AS director
        INNER JOIN #CandidatePayload AS actress
            ON actress.PlayId = play.Id AND actress.AwardCategoryCode = 1003
        INNER JOIN #CandidatePayload AS actor
            ON actor.PlayId = play.Id AND actor.AwardCategoryCode = 1004
        INNER JOIN #CandidatePayload AS supportActress
            ON supportActress.PlayId = play.Id AND supportActress.AwardCategoryCode = 1005
        INNER JOIN #CandidatePayload AS supportActor
            ON supportActor.PlayId = play.Id AND supportActor.AwardCategoryCode = 1006
        INNER JOIN #CandidatePayload AS stageDesign
            ON stageDesign.PlayId = play.Id AND stageDesign.AwardCategoryCode = 1007
        INNER JOIN #CandidatePayload AS clothesDesign
            ON clothesDesign.PlayId = play.Id AND clothesDesign.AwardCategoryCode = 1008
        INNER JOIN #CandidatePayload AS stageMusic
            ON stageMusic.PlayId = play.Id AND stageMusic.AwardCategoryCode = 1009
        INNER JOIN #CandidatePayload AS lightDesign
            ON lightDesign.PlayId = play.Id AND lightDesign.AwardCategoryCode = 1010
        INNER JOIN #CandidatePayload AS choreography
            ON choreography.PlayId = play.Id AND choreography.AwardCategoryCode = 1011
        WHERE @PlayId IS NULL OR play.Id = @PlayId;

        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
