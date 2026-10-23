/*
    Keeps the editable admin projection and its source Form in sync.  The Form
    remains the import contract, while edits made through Plays or
    PlayAwardCategories are written back so a later Form synchronization cannot
    restore stale names or photos.
*/
CREATE OR ALTER PROCEDURE dbo.usp_SynchronizePlayDataToForms
    @PlayId uniqueidentifier = NULL,
    @PlayIdsJson nvarchar(max) = NULL,
    @SyncCandidateData bit = 1
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* Preserve the scalar and no-argument maintenance APIs. Trigger callers
       submit one set of affected Plays instead of invoking this proc per row. */
    CREATE TABLE #ReverseSyncPlays (PlayId uniqueidentifier NOT NULL PRIMARY KEY);
    IF @PlayIdsJson IS NULL
    BEGIN
        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT Id FROM dbo.Plays
        WHERE SourceFormId IS NOT NULL AND (@PlayId IS NULL OR Id = @PlayId);
    END
    ELSE
    BEGIN
        IF ISJSON(@PlayIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@PlayIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@PlayIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier, JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT DISTINCT play.Id
        FROM OPENJSON(@PlayIdsJson) AS scopeItem
        INNER JOIN dbo.Plays AS play
            ON play.Id = CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        WHERE play.SourceFormId IS NOT NULL AND (@PlayId IS NULL OR play.Id = @PlayId);
    END;

    IF NOT EXISTS (SELECT 1 FROM #ReverseSyncPlays)
        RETURN;

    SET @SyncCandidateData = COALESCE(@SyncCandidateData, 1);
    EXEC sys.sp_set_session_context
        @key = N'PlayToFormSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* A Play metadata edit must leave every imported JSON byte intact and
           must not read candidate image blobs or repair unrelated source slots. */
        IF @SyncCandidateData = 0
        BEGIN
            UPDATE formRecord
            SET RepertoireName = play.PlayName,
                TheatreName = play.TheaterName,
                Phone = COALESCE(play.Phone, formRecord.Phone),
                ContactName = play.ContactPersonName,
                ContactPhone = play.ContactPersonPhone,
                Email = COALESCE(play.Email, formRecord.Email),
                IsActive = play.IsActive,
                IsPublished = play.IsPublished,
                UpdatedDate = @Now
            FROM dbo.Form AS formRecord
            INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            WHERE EXISTS
            (
                SELECT CONVERT(varbinary(max), play.PlayName),
                       CONVERT(varbinary(max), play.TheaterName),
                       CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                       CONVERT(varbinary(max), play.ContactPersonName),
                       CONVERT(varbinary(max), play.ContactPersonPhone),
                       CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                       play.IsActive, play.IsPublished
                EXCEPT
                SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                       CONVERT(varbinary(max), formRecord.TheatreName),
                       CONVERT(varbinary(max), formRecord.Phone),
                       CONVERT(varbinary(max), formRecord.ContactName),
                       CONVERT(varbinary(max), formRecord.ContactPhone),
                       CONVERT(varbinary(max), formRecord.Email),
                       formRecord.IsActive, formRecord.IsPublished
            );
        END
        ELSE
        BEGIN
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
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
            WHERE play.SourceFormId IS NOT NULL
              AND candidate.AwardCategoryCode BETWEEN 1003 AND 1011
              AND (formRecord.previousProductionVersion = 0
                   OR candidate.AwardCategoryCode BETWEEN 1003 AND 1006)
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
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        CROSS JOIN
        (
            VALUES (1003), (1004), (1005), (1006), (1007),
                   (1008), (1009), (1010), (1011)
        ) AS category(AwardCategoryCode)
        WHERE play.SourceFormId IS NOT NULL
          AND (formRecord.previousProductionVersion = 0
               OR category.AwardCategoryCode BETWEEN 1003 AND 1006);

        UPDATE formRecord
        SET
            RepertoireName = play.PlayName,
            TheatreName = play.TheaterName,
            Phone = COALESCE(play.Phone, formRecord.Phone),
            ContactName = play.ContactPersonName,
            ContactPhone = play.ContactPersonPhone,
            Email = COALESCE(play.Email, formRecord.Email),
            Director = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                            ELSE COALESCE(director.Candidate, formRecord.Director) END,
            LeadActress = actress.CandidateJson,
            LeadActor = actor.CandidateJson,
            SupportActress = supportActress.CandidateJson,
            SupportActor = supportActor.CandidateJson,
            StageDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END,
            ClothesDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END,
            StageMusic = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END,
            LightDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END,
            Choreography = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END,
            IsActive = play.IsActive,
            IsPublished = play.IsPublished,
            UpdatedDate = @Now
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        OUTER APPLY
        (
            SELECT TOP (1) candidate.Candidate
            FROM dbo.PlayAwardCategories AS candidate
            WHERE candidate.PlayId = play.Id
              AND formRecord.previousProductionVersion = 0
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
        LEFT JOIN #CandidatePayload AS stageDesign
            ON stageDesign.PlayId = play.Id AND stageDesign.AwardCategoryCode = 1007
        LEFT JOIN #CandidatePayload AS clothesDesign
            ON clothesDesign.PlayId = play.Id AND clothesDesign.AwardCategoryCode = 1008
        LEFT JOIN #CandidatePayload AS stageMusic
            ON stageMusic.PlayId = play.Id AND stageMusic.AwardCategoryCode = 1009
        LEFT JOIN #CandidatePayload AS lightDesign
            ON lightDesign.PlayId = play.Id AND lightDesign.AwardCategoryCode = 1010
        LEFT JOIN #CandidatePayload AS choreography
            ON choreography.PlayId = play.Id AND choreography.AwardCategoryCode = 1011
        WHERE EXISTS
        (
            SELECT CONVERT(varbinary(max), play.PlayName),
                   CONVERT(varbinary(max), play.TheaterName),
                   CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                   CONVERT(varbinary(max), play.ContactPersonName),
                   CONVERT(varbinary(max), play.ContactPersonPhone),
                   CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                       ELSE COALESCE(director.Candidate, formRecord.Director) END),
                   CONVERT(varbinary(max), actress.CandidateJson),
                   CONVERT(varbinary(max), actor.CandidateJson),
                   CONVERT(varbinary(max), supportActress.CandidateJson),
                   CONVERT(varbinary(max), supportActor.CandidateJson),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END),
                   play.IsActive, play.IsPublished
            EXCEPT
            SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                   CONVERT(varbinary(max), formRecord.TheatreName),
                   CONVERT(varbinary(max), formRecord.Phone),
                   CONVERT(varbinary(max), formRecord.ContactName),
                   CONVERT(varbinary(max), formRecord.ContactPhone),
                   CONVERT(varbinary(max), formRecord.Email),
                   CONVERT(varbinary(max), formRecord.Director),
                   CONVERT(varbinary(max), formRecord.LeadActress),
                   CONVERT(varbinary(max), formRecord.LeadActor),
                   CONVERT(varbinary(max), formRecord.SupportActress),
                   CONVERT(varbinary(max), formRecord.SupportActor),
                   CONVERT(varbinary(max), formRecord.StageDesign),
                   CONVERT(varbinary(max), formRecord.ClothesDesign),
                   CONVERT(varbinary(max), formRecord.StageMusic),
                   CONVERT(varbinary(max), formRecord.LightDesign),
                   CONVERT(varbinary(max), formRecord.Choreography),
                   formRecord.IsActive, formRecord.IsPublished
        );
        END;

        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
