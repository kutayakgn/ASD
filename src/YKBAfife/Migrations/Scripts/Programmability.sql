CREATE OR ALTER PROCEDURE [dbo].[usp_ReassignFormSeasons]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;

        UPDATE formRecord
        SET SeasonId = selectedSeason.Id
        FROM dbo.Form AS formRecord
        OUTER APPLY
        (
            SELECT TOP (1) season.Id
            FROM dbo.Seasons AS season
            WHERE season.IsPublished = 1
              AND formRecord.CreatedDate IS NOT NULL
              AND CAST(formRecord.CreatedDate AS date) >= season.SeasonStartDate
              AND CAST(formRecord.CreatedDate AS date) < season.SeasonEndDate
            ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
        ) AS selectedSeason
        WHERE formRecord.SeasonId <> selectedSeason.Id
           OR (formRecord.SeasonId IS NULL AND selectedSeason.Id IS NOT NULL)
           OR (formRecord.SeasonId IS NOT NULL AND selectedSeason.Id IS NULL);

        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshRankings]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshInProgress')) = 1
        RETURN;

    DECLARE @ApplicationLockResult int;
    EXEC @ApplicationLockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Rankings.Refresh',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @ApplicationLockResult < 0
        THROW 52001, N'Rankings refresh lock could not be acquired.', 1;

    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshInProgress',
        @value = 1;
    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshAuthorized',
        @value = 1;

    BEGIN TRY
        ;WITH EligibleCandidates AS
        (
            SELECT
                candidate.Id AS PlayAwardCategoryId,
                candidate.PlayId,
                candidate.AwardCategoryCode
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE play.RecordType = 0
              AND play.IsPublished = 1
              AND play.IsActive = 1
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
              AND candidate.IsActive = 1
        ),
        OrderedActiveVotes AS
        (
            SELECT
                eligible.PlayAwardCategoryId,
                vote.Score,
                ROW_NUMBER() OVER
                (
                    PARTITION BY eligible.PlayAwardCategoryId
                    ORDER BY vote.Score, vote.Id
                ) AS ScoreOrder,
                COUNT_BIG(*) OVER
                (
                    PARTITION BY eligible.PlayAwardCategoryId
                ) AS VoteCount
            FROM EligibleCandidates AS eligible
            INNER JOIN dbo.JuryVotes AS vote
                ON vote.PlayAwardCategoryId = eligible.PlayAwardCategoryId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
        ),
        VoteStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                COUNT_BIG(*) AS NumberOfActiveVote,
                AVG(CONVERT(float, Score)) AS ArithmeticMean,
                VAR(CONVERT(float, Score)) AS ArithmeticVariance
            FROM OrderedActiveVotes
            GROUP BY PlayAwardCategoryId
        ),
        TrimmedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                AVG(CONVERT(float, Score)) AS TrimmedMean
            FROM OrderedActiveVotes
            WHERE VoteCount >= 3
              AND ScoreOrder > 1
              AND ScoreOrder < VoteCount
            GROUP BY PlayAwardCategoryId
        ),
        CandidateStatistics AS
        (
            SELECT
                eligible.PlayAwardCategoryId,
                eligible.PlayId,
                eligible.AwardCategoryCode,
                CONVERT(int, COALESCE(voteStats.NumberOfActiveVote, 0))
                    AS NumberOfActiveVote,
                voteStats.ArithmeticMean,
                trimmed.TrimmedMean,
                voteStats.ArithmeticVariance
            FROM EligibleCandidates AS eligible
            LEFT JOIN VoteStatistics AS voteStats
                ON voteStats.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
            LEFT JOIN TrimmedStatistics AS trimmed
                ON trimmed.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
        ),
        RankedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                PlayId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                CASE
                    WHEN ArithmeticMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN ArithmeticMean IS NULL THEN 1 ELSE 0 END,
                                ArithmeticMean DESC
                        )
                    )
                END AS ArithmeticRank,
                CASE
                    WHEN TrimmedMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN TrimmedMean IS NULL THEN 1 ELSE 0 END,
                                TrimmedMean DESC
                        )
                    )
                END AS TrimmedRank,
                ArithmeticVariance,
                CASE
                    WHEN ArithmeticVariance IS NULL THEN NULL
                    WHEN ArithmeticVariance >= 6.064 THEN 1
                    WHEN ArithmeticVariance >= 4.987 THEN 2
                    WHEN ArithmeticVariance >= 4.141 THEN 3
                    ELSE 4
                END AS ConfidenceValue
            FROM CandidateStatistics
        )
        MERGE dbo.Rankings WITH (HOLDLOCK) AS target
        USING RankedStatistics AS source
            ON source.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHEN MATCHED AND
        (
            target.PlayId <> source.PlayId
            OR target.NumberOfActiveVote <> source.NumberOfActiveVote
            OR target.IsPublished = 0
            OR target.ArithmeticMean <> source.ArithmeticMean
            OR (target.ArithmeticMean IS NULL AND source.ArithmeticMean IS NOT NULL)
            OR (target.ArithmeticMean IS NOT NULL AND source.ArithmeticMean IS NULL)
            OR target.TrimmedMean <> source.TrimmedMean
            OR (target.TrimmedMean IS NULL AND source.TrimmedMean IS NOT NULL)
            OR (target.TrimmedMean IS NOT NULL AND source.TrimmedMean IS NULL)
            OR target.ArithmeticRank <> source.ArithmeticRank
            OR (target.ArithmeticRank IS NULL AND source.ArithmeticRank IS NOT NULL)
            OR (target.ArithmeticRank IS NOT NULL AND source.ArithmeticRank IS NULL)
            OR target.TrimmedRank <> source.TrimmedRank
            OR (target.TrimmedRank IS NULL AND source.TrimmedRank IS NOT NULL)
            OR (target.TrimmedRank IS NOT NULL AND source.TrimmedRank IS NULL)
            OR target.ArithmeticVariance <> source.ArithmeticVariance
            OR
            (
                target.ArithmeticVariance IS NULL
                AND source.ArithmeticVariance IS NOT NULL
            )
            OR
            (
                target.ArithmeticVariance IS NOT NULL
                AND source.ArithmeticVariance IS NULL
            )
            OR target.ConfidenceValue <> source.ConfidenceValue
            OR (target.ConfidenceValue IS NULL AND source.ConfidenceValue IS NOT NULL)
            OR (target.ConfidenceValue IS NOT NULL AND source.ConfidenceValue IS NULL)
        )
            THEN UPDATE SET
                PlayId = source.PlayId,
                NumberOfActiveVote = source.NumberOfActiveVote,
                ArithmeticMean = source.ArithmeticMean,
                TrimmedMean = source.TrimmedMean,
                ArithmeticRank = source.ArithmeticRank,
                TrimmedRank = source.TrimmedRank,
                ArithmeticVariance = source.ArithmeticVariance,
                ConfidenceValue = source.ConfidenceValue,
                IsPublished = 1
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                Id,
                PlayId,
                PlayAwardCategoryId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                ArithmeticRank,
                TrimmedRank,
                ArithmeticVariance,
                ConfidenceValue,
                IsPublished
            )
            VALUES
            (
                NEWID(),
                source.PlayId,
                source.PlayAwardCategoryId,
                source.NumberOfActiveVote,
                source.ArithmeticMean,
                source.TrimmedMean,
                source.ArithmeticRank,
                source.TrimmedRank,
                source.ArithmeticVariance,
                source.ConfidenceValue,
                1
            )
        WHEN NOT MATCHED BY SOURCE AND target.IsPublished = 1
            THEN UPDATE SET IsPublished = 0;

        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshAuthorized',
            @value = NULL;
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshInProgress',
            @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Rankings.Refresh',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshAuthorized',
            @value = NULL;
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshInProgress',
            @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Rankings.Refresh',
            @LockOwner = N'Session';
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshSeasonStatistics]
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;

    UPDATE season
    SET
        PlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        ActivePlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.StatusCode = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        VoteCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.JuryVotes AS vote
            INNER JOIN dbo.PlayAwardCategories AS candidate
                ON candidate.Id = vote.PlayAwardCategoryId
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
              AND candidate.IsPublished = 1
              AND candidate.IsActive = 1
              AND play.IsPublished = 1
              AND play.IsActive = 1
              AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        )
    FROM dbo.Seasons AS season
    WHERE season.IsPublished = 1
      AND
      (
          @FromDate IS NULL
          OR
          (
              @FromDate < CONVERT(datetime2(7), season.SeasonEndDate)
              AND @ToDate >= CONVERT(datetime2(7), season.SeasonStartDate)
          )
      );
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormCandidates]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

    CREATE TABLE #CandidateSource
    (
        SourceOrder int NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NULL,
        ImageUrl nvarchar(255) NULL,
        Base64 nvarchar(max) NULL
    );

    /* Director is the mandatory, single-slot category 1002 candidate. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT 0, play.Id, 1002, LEFT(LTRIM(RTRIM(formRecord.Director)), 250),
           NULL, 0, NULL, NULL
    FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NOT NULL;

    /* Every category except 1001/1002 creates one role-scoped row per JSON item. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT CONVERT(int, jsonItem.[key]) + 1,
           play.Id,
           category.AwardCategoryCode,
           LEFT(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.Name'))), 250),
           LEFT(COALESCE
           (
               NULLIF(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.Role'))), N''),
               NULLIF(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.Name'))), N'')
           ), 200),
           NULL,
           LEFT(NULLIF(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.ImageUrl'))), N''), 255),
           NULLIF(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.Base64'))), N'')
    FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    CROSS APPLY
    (
        VALUES
            (1003, formRecord.LeadActress),
            (1004, formRecord.LeadActor),
            (1005, formRecord.SupportActress),
            (1006, formRecord.SupportActor),
            (1007, formRecord.StageDesign),
            (1008, formRecord.ClothesDesign),
            (1009, formRecord.StageMusic),
            (1010, formRecord.LightDesign),
            (1011, formRecord.Choreography),
            (1012, formRecord.YoungGenerationArtist)
    ) AS category(AwardCategoryCode, CandidateJson)
    CROSS APPLY OPENJSON
    (
        CASE
            WHEN ISJSON(category.CandidateJson) <> 1 THEN N'[]'
            WHEN LEFT(LTRIM(category.CandidateJson), 1) = N'[' THEN category.CandidateJson
            ELSE N'[' + category.CandidateJson + N']'
        END
    ) AS jsonItem
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(JSON_VALUE(jsonItem.value, N'$.Name'))), N'') IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #CandidateSource
        WHERE AwardCategoryCode BETWEEN 1003 AND 1012
          AND NULLIF(LTRIM(RTRIM(Role)), N'') IS NULL
    )
        THROW 52410, N'Oyuncu ve Genç Kuşak adaylarında Role alanı zorunludur.', 1;

    IF EXISTS
    (
        SELECT PlayId, AwardCategoryCode, LOWER(LTRIM(RTRIM(Role)))
        FROM #CandidateSource
        WHERE Role IS NOT NULL
        GROUP BY PlayId, AwardCategoryCode, LOWER(LTRIM(RTRIM(Role)))
        HAVING COUNT(*) > 1
    )
        THROW 52411, N'Aynı kategori içinde aynı rol birden fazla kez gönderilemez.', 1;

    UPDATE source
    SET RoleCode = existing.RoleCode
    FROM #CandidateSource AS source
    CROSS APPLY
    (
        SELECT TOP (1) candidate.RoleCode
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.PlayId = source.PlayId
          AND candidate.AwardCategoryCode = source.AwardCategoryCode
          AND candidate.Role IS NOT NULL
          AND LOWER(LTRIM(RTRIM(candidate.Role))) = LOWER(LTRIM(RTRIM(source.Role)))
        ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                 COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC, candidate.Id
    ) AS existing
    WHERE source.Role IS NOT NULL;

    ;WITH MissingRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               COALESCE
               (
                   (SELECT MAX(candidate.RoleCode)
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.PlayId = source.PlayId AND candidate.RoleCode > 0),
                   0
               ) + ROW_NUMBER() OVER
                   (PARTITION BY source.PlayId ORDER BY source.AwardCategoryCode, source.SourceOrder) AS NewRoleCode
        FROM #CandidateSource AS source
        WHERE source.Role IS NOT NULL AND source.RoleCode IS NULL
    )
    UPDATE source
    SET RoleCode = missing.NewRoleCode
    FROM #CandidateSource AS source
    INNER JOIN MissingRoles AS missing
        ON missing.PlayId = source.PlayId
       AND missing.AwardCategoryCode = source.AwardCategoryCode
       AND missing.SourceOrder = source.SourceOrder;

    CREATE TABLE #NewCandidates
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        ImageId uniqueidentifier NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #NewCandidates
        (CandidateId, ImageId, PlayId, AwardCategoryCode, Candidate, Role,
         RoleCode, ImageUrl, CleanBase64)
    SELECT NEWID(), CASE WHEN source.Base64 IS NULL THEN NULL ELSE NEWID() END,
           source.PlayId, source.AwardCategoryCode, source.Candidate, source.Role,
           COALESCE(source.RoleCode, 0), source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = source.PlayId
          AND existing.AwardCategoryCode = source.AwardCategoryCode
          AND existing.RoleCode = COALESCE(source.RoleCode, 0)
          AND existing.IsPublished = 1
    );

    /* Legacy/test Forms can contain placeholder strings in Base64. They must not
       block candidate backfill and must never be persisted as image bytes. */
    UPDATE candidate
    SET ImageId = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL
      AND
      (
          LEN(candidate.CleanBase64) % 4 <> 0
          OR candidate.CleanBase64 COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/=]%'
      );

    UPDATE candidate
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("candidate.CleanBase64"))', 'varbinary(max)')
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL;

    UPDATE candidate
    SET ContentType = CASE
        WHEN SUBSTRING(candidate.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(candidate.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(candidate.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(candidate.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL;

    UPDATE candidate
    SET ImageId = NULL, ImageData = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL
      AND
      (
          DATALENGTH(candidate.ImageData) = 0
          OR DATALENGTH(candidate.ImageData) > 5 * 1024 * 1024
          OR candidate.ContentType IS NULL
      );

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT candidate.ImageId,
           COALESCE(NULLIF(candidate.ImageUrl, N''),
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), candidate.CandidateId),
                           CASE candidate.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           candidate.ContentType, candidate.ImageData, @Now, candidate.CandidateId, 1
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageId IS NOT NULL;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, IsActive, Candidate, AwardCategoryCode,
        IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT candidate.CandidateId, candidate.PlayId, @Now, NULL, NULL, NULL,
           1, 1, candidate.Candidate, candidate.AwardCategoryCode,
           1, candidate.Role, candidate.RoleCode, candidate.ImageId
    FROM #NewCandidates AS candidate;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormsToPlays]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    DECLARE @LockResult int;
    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @LockResult < 0
        THROW 52403, N'Form senkronizasyon kilidi alınamadı.', 1;

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* Link a unique exact legacy match before creating a new play. */
        ;WITH ExactMatches AS
        (
            SELECT
                formRecord.Id AS FormId,
                play.Id AS PlayId,
                COUNT_BIG(*) OVER (PARTITION BY formRecord.Id) AS PlayMatchCount,
                COUNT_BIG(*) OVER (PARTITION BY play.Id) AS FormMatchCount
            FROM dbo.Form AS formRecord
            INNER JOIN dbo.Plays AS play
                ON play.RecordType = 0
               AND play.SourceFormId IS NULL
               AND LOWER(LTRIM(RTRIM(play.PlayName))) =
                   LOWER(LTRIM(RTRIM(formRecord.RepertoireName)))
               AND LOWER(LTRIM(RTRIM(play.TheaterName))) =
                   LOWER(LTRIM(RTRIM(formRecord.TheatreName)))
        )
        UPDATE play
        SET SourceFormId = exact.FormId,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN ExactMatches AS exact ON exact.PlayId = play.Id
        WHERE exact.PlayMatchCount = 1
          AND exact.FormMatchCount = 1;

        INSERT INTO dbo.Plays
        (
            Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt,
            UpdatedBy, IsPublished, Slug, TheaterName, Phone,
            ContactPersonName, ContactPersonPhone, Address, Email,
            JuriOylamaStatus, KunyeGirisStatus, RecordType,
            SourceFormId, IsActive
        )
        SELECT
            NEWID(),
            formRecord.RepertoireName,
            1,
            formRecord.CreatedDate,
            NULL,
            formRecord.UpdatedDate,
            NULL,
            1,
            LOWER
            (
                CONCAT
                (
                    'kunye-',
                    REPLACE(formRecord.ApplicationNumber, ' ', '-'),
                    '-',
                    LEFT(CONVERT(varchar(36), formRecord.Id), 8)
                )
            ),
            formRecord.TheatreName,
            formRecord.Phone,
            COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            NULL,
            formRecord.Email,
            1,
            1,
            0,
            formRecord.Id,
            1
        FROM dbo.Form AS formRecord
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Plays AS play
              WHERE play.SourceFormId = formRecord.Id
          );

        UPDATE play
        SET
            PlayName = formRecord.RepertoireName,
            CreatedAt = formRecord.CreatedDate,
            UpdatedAt = COALESCE(formRecord.UpdatedDate, @Now),
            TheaterName = formRecord.TheatreName,
            Phone = formRecord.Phone,
            ContactPersonName =
                COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            ContactPersonPhone =
                COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            Email = formRecord.Email
        FROM dbo.Plays AS play
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        WHERE play.RecordType = 0
          AND
          (
              play.PlayName <> formRecord.RepertoireName
              OR play.CreatedAt <> formRecord.CreatedDate
              OR play.TheaterName <> formRecord.TheatreName
              OR COALESCE(play.Phone, N'') <> COALESCE(formRecord.Phone, N'')
              OR COALESCE(play.ContactPersonName, N'') <>
                    COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName)
              OR COALESCE(play.ContactPersonPhone, N'') <>
                    COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone)
              OR COALESCE(play.Email, N'') <> COALESCE(formRecord.Email, N'')
          );

        EXEC dbo.usp_SynchronizeFormCandidates;

        CREATE TABLE #DeactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #DeactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        WHERE play.IsActive = 1
          AND (formRecord.IsPublished = 0 OR formRecord.IsActive = 0);

        INSERT INTO dbo.FormLifecycleStates
        (
            Id, FormId, EntityName, EntityId, WasPublished, WasActive,
            WasJuriOylamaStatus, WasKunyeGirisStatus, WasStatusCode,
            DeactivatedAt, RestoredAt, IsPublished
        )
        SELECT
            NEWID(), affected.FormId, N'Play', play.Id,
            play.IsPublished, play.IsActive,
            play.JuriOylamaStatus, play.KunyeGirisStatus, play.StatusCode,
            @Now, NULL, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Plays AS play ON play.Id = affected.PlayId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.FormLifecycleStates AS state
            WHERE state.FormId = affected.FormId
              AND state.EntityName = N'Play'
              AND state.EntityId = play.Id
              AND state.IsPublished = 1
        );

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'PlayAwardCategory', candidate.Id,
               candidate.IsPublished, candidate.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        WHERE candidate.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryVote', vote.Id,
               vote.IsPublished, vote.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        INNER JOIN dbo.JuryVotes AS vote
            ON vote.PlayAwardCategoryId = candidate.Id
        WHERE vote.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryGameTicketFee', ticket.Id,
               ticket.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryGameTicketFees AS ticket
            ON ticket.PlayId = affected.PlayId
        WHERE ticket.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryAssignedPlay', assignment.Id,
               assignment.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryAssignedPlays AS assignment
            ON assignment.PlayId = affected.PlayId
        WHERE assignment.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'Blacklist', blacklist.Id,
               blacklist.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Blacklist AS blacklist
            ON blacklist.PlayId = affected.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE vote
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE vote.IsPublished = 1 OR vote.IsActive = 1;

        UPDATE candidate
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE candidate.IsPublished = 1 OR candidate.IsActive = 1;

        UPDATE ticket
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = ticket.PlayId
        WHERE ticket.IsPublished = 1;

        UPDATE assignment
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = assignment.PlayId
        WHERE assignment.IsPublished = 1;

        UPDATE blacklist
        SET IsPublished = 0
        FROM dbo.Blacklist AS blacklist
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = blacklist.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE play
        SET IsActive = 0,
            JuriOylamaStatus = 0,
            KunyeGirisStatus = 0,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #DeactivateForms AS affected ON affected.PlayId = play.Id;

        CREATE TABLE #ReactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #ReactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND play.IsActive = 0
          AND EXISTS
          (
              SELECT 1 FROM dbo.FormLifecycleStates AS state
              WHERE state.FormId = formRecord.Id
                AND state.EntityName = N'Play'
                AND state.EntityId = play.Id
                AND state.IsPublished = 1
          );

        UPDATE play
        SET IsActive = 1,
            JuriOylamaStatus = state.WasJuriOylamaStatus,
            KunyeGirisStatus = state.WasKunyeGirisStatus,
            StatusCode = state.WasStatusCode,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #ReactivateForms AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.FormId = affected.FormId
           AND state.EntityName = N'Play'
           AND state.EntityId = play.Id
           AND state.IsPublished = 1;

        UPDATE candidate
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'PlayAwardCategory'
           AND state.EntityId = candidate.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE vote
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryVote'
           AND state.EntityId = vote.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE ticket
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryGameTicketFee'
           AND state.EntityId = ticket.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE assignment
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryAssignedPlay'
           AND state.EntityId = assignment.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE blacklist
        SET IsPublished = state.WasPublished
        FROM dbo.Blacklist AS blacklist
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'Blacklist'
           AND state.EntityId = blacklist.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE state
        SET IsPublished = 0, RestoredAt = @Now
        FROM dbo.FormLifecycleStates AS state
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        WHERE state.IsPublished = 1;

        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- The 1001 row is a system-managed category slot, not a person candidate.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE candidate.AwardCategoryCode = 1001
          AND
          (
              play.RecordType <> 0
              OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
              OR candidate.Candidate <> play.TheaterName
              OR (candidate.RoleCode = 0 AND candidate.IsCurrent <> 1)
              OR
              (
                  candidate.RoleCode <> 0
                  AND
                  (
                      previousCandidate.Id IS NULL
                      OR previousCandidate.PlayId <> candidate.PlayId
                      OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                      OR previousCandidate.RoleCode <> candidate.RoleCode
                  )
              )
          )
    )
    BEGIN
        THROW 51302, N'1001 varsayilan oyun kategorisi sistem tarafindan yonetilir ve degistirilemez.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.Id IS NULL
           OR previousCandidate.PlayId <> candidate.PlayId
           OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
           OR previousCandidate.RoleCode <> candidate.RoleCode
           OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND (candidate.RoleCode <= 0 OR NULLIF(LTRIM(RTRIM(candidate.Role)), N'') IS NULL)
        )
        BEGIN
            THROW 51303, N'Cok adayli kategorilerde pozitif RoleCode ve dolu Role alani zorunludur.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            OUTER APPLY
            (
                SELECT TOP (1) existing.RoleCode
                FROM dbo.PlayAwardCategories AS existing
                WHERE existing.Id <> candidate.Id
                  AND existing.PlayId = candidate.PlayId
                  AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                ORDER BY
                    existing.IsCurrent DESC,
                    COALESCE(existing.UpdatedAt, existing.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    existing.Id
            ) AS canonicalSlot
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 0
                AND candidate.AwardCategoryCode <> 1001
                AND
                (
                    candidate.Role IS NOT NULL
                    OR candidate.RoleCode <> COALESCE(canonicalSlot.RoleCode, 0)
                )
        )
        BEGIN
            THROW 51304, N'Tek adayli kategoriler yalnizca tek mantiksal slot ve bos Role alani kullanabilir.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            INNER JOIN dbo.PlayAwardCategories AS existing
                ON existing.Id <> candidate.Id
               AND existing.PlayId = candidate.PlayId
               AND existing.AwardCategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND
                (
                    (existing.RoleCode = candidate.RoleCode AND LTRIM(RTRIM(existing.Role)) <> LTRIM(RTRIM(candidate.Role)))
                    OR
                    (existing.RoleCode <> candidate.RoleCode AND LTRIM(RTRIM(existing.Role)) = LTRIM(RTRIM(candidate.Role)))
                )
        )
        BEGIN
            THROW 51305, N'Bir rol adi tek RoleCode ile, bir RoleCode da tek rol adi ile eslesmelidir.', 1;
        END;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        INNER JOIN dbo.AwardCategories AS category
            ON category.CategoryCode = candidate.AwardCategoryCode
        WHERE category.MultiCandidate = 0
          AND (previousCandidate.Id IS NULL OR previousCandidate.IsCurrent <> candidate.IsCurrent)
          AND
          (
              SELECT COUNT_BIG(*)
              FROM dbo.PlayAwardCategories AS currentCandidate
              WHERE currentCandidate.PlayId = candidate.PlayId
                AND currentCandidate.AwardCategoryCode = candidate.AwardCategoryCode
                AND currentCandidate.IsCurrent = 1
          ) > 1
    )
    BEGIN
        THROW 51306, N'Tek adayli kategorilerde ayni anda yalnizca bir guncel aday olabilir.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_EnsureDefaultAwardCategory
ON dbo.Plays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE defaultCategory
    SET
        defaultCategory.Candidate = currentPlay.TheaterName,
        defaultCategory.Role = N'Tiyatro',
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND
      (
          currentPlay.TheaterName <> previousPlay.TheaterName
          OR defaultCategory.Candidate <> currentPlay.TheaterName
          OR ISNULL(defaultCategory.Role, N'') <> N'Tiyatro'
      );

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        play.IsPublished,
        play.TheaterName,
        1001,
        1,
        N'Tiyatro',
        0,
        NULL
    FROM inserted AS play
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_ProtectDefaultCategory
ON dbo.PlayAwardCategories
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND candidate.RoleCode = 0
          AND play.RecordType = 0
    )
    BEGIN
        THROW 51307, N'Kunye oyunlarinin varsayilan 1001 kategori kaydi silinemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotings_SoftDelete
ON dbo.AdditionalVotings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2(7) = SYSDATETIME();
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotings target INNER JOIN deleted d ON d.Id = target.Id;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingJuries_SoftDelete ON dbo.AdditionalVotingJuries INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingPlays_SoftDelete ON dbo.AdditionalVotingPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingUsages_SoftDelete ON dbo.AdditionalVotingUsages INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_PlayAwardCategories_BlockAdminPlay]
ON [dbo].[PlayAwardCategories]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = candidate.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51211, N'RecordType 1 olan oyunlara aday veya ödül kategorisi eklenemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_BlockAdminPlay]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS blacklist
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = blacklist.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51213, N'RecordType 1 olan oyunlara blacklist kaydı eklenemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_RecordTypeImmutable]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE currentPlay.[RecordType] <> previousPlay.[RecordType]
    )
    BEGIN
        THROW 51231, N'Mevcut bir oyunun RecordType degeri degistirilemez.', 1;
    END;
END;
GO

/* A new published vote soft-deletes every older vote in the same logical role. */
CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SingleRecordPerPlayCategoryRole
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedGroups TABLE
    (
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        RoleCode int NOT NULL,
        WinnerVoteId uniqueidentifier NOT NULL,
        PRIMARY KEY (JuryId, PlayId, AwardCategoryCode, RoleCode)
    );

    ;WITH ChangedVotes AS
    (
        SELECT
            changedVote.Id,
            changedVote.JuryId,
            candidate.PlayId,
            candidate.AwardCategoryCode,
            candidate.RoleCode,
            ROW_NUMBER() OVER
            (
                PARTITION BY changedVote.JuryId, candidate.PlayId,
                    candidate.AwardCategoryCode, candidate.RoleCode
                ORDER BY COALESCE(changedVote.UpdatedAt, changedVote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, changedVote.Id DESC
            ) AS VoteOrder
        FROM inserted AS changedVote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changedVote.PlayAwardCategoryId
        WHERE changedVote.IsPublished = 1
    )
    INSERT INTO @AffectedGroups
        (JuryId, PlayId, AwardCategoryCode, RoleCode, WinnerVoteId)
    SELECT JuryId, PlayId, AwardCategoryCode, RoleCode, Id
    FROM ChangedVotes
    WHERE VoteOrder = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN @AffectedGroups AS affected
        ON affected.JuryId = vote.JuryId
       AND affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode
    WHERE vote.Id <> affected.WinnerVoteId
      AND vote.IsPublished = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE (candidate.IsPublished = 0 AND vote.IsPublished = 1)
       OR (candidate.IsActive = 0 AND vote.IsActive = 1);
END;
GO

/* Direct SQL deletes are also soft deletes. */
CREATE OR ALTER TRIGGER dbo.TR_Announcements_SoftDelete ON dbo.Announcements INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Announcements target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AwardCategories_SoftDelete ON dbo.AwardCategories INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.AwardCategories target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_SoftDelete ON dbo.Blacklist INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Blacklist target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Configs_SoftDelete ON dbo.Configs INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Configs target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Group_SoftDelete ON dbo.[Group] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Group] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Images_SoftDelete ON dbo.Images INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Images target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_SoftDelete ON dbo.JuryAssignedPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryAssignedPlays target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_SoftDelete ON dbo.JuryGameTicketFees INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryGameTicketFees target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SoftDelete ON dbo.JuryVotes INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.JuryVotes target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Log_SoftDelete ON dbo.[Log] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Log] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Manager_SoftDelete ON dbo.[Manager] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Manager] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SoftDelete
ON dbo.PlayAwardCategories
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE AwardCategoryCode = 1001 AND RoleCode = 0)
        THROW 51307, N'System-managed category 1001 cannot be deleted.', 1;

    UPDATE target
    SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories target
    INNER JOIN deleted source ON source.Id = target.Id;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.Plays target
    INNER JOIN deleted source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayStatuses_SoftDelete ON dbo.PlayStatuses INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.PlayStatuses target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Roles_SoftDelete ON dbo.Roles INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Roles target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDelete ON dbo.Users INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.Users target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_UsersLog_SoftDelete ON dbo.UsersLog INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.UsersLog target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

/* EF soft deletes are UPDATE operations, so dependent rows are soft-deleted here. */
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDeleteDependents
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE candidate
    SET candidate.IsPublished = 0,
        candidate.IsActive = 0,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories candidate
    INNER JOIN inserted play ON play.Id = candidate.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND candidate.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted play ON play.Id = assignment.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted play ON play.Id = fee.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted play ON play.Id = blacklist.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDeleteDependents
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE vote SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes vote
    INNER JOIN inserted jury ON jury.Id = vote.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND vote.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted jury ON jury.Id = assignment.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted jury ON jury.Id = fee.UserId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted jury ON jury.Id = blacklist.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    EXEC dbo.usp_SynchronizeFormsToPlays;
END;
GO

/* Lifecycle sync restores votes explicitly from snapshots. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET vote.IsActive = candidate.IsActive,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsActive <> candidate.IsActive
          AND vote.IsPublished = 1
          AND vote.IsActive <> candidate.IsActive;
    END;

    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR vote.IsActive <> CASE
                    WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END
          );
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    ;WITH AffectedGroups AS
    (
        SELECT PlayId, AwardCategoryCode, RoleCode FROM inserted
        UNION
        SELECT PlayId, AwardCategoryCode, RoleCode FROM deleted
    ),
    RankedVotes AS
    (
        SELECT vote.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY vote.JuryId, candidate.PlayId,
                       candidate.AwardCategoryCode, candidate.RoleCode
                   ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                       CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
               ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN AffectedGroups AS affected
            ON affected.PlayId = candidate.PlayId
           AND affected.AwardCategoryCode = candidate.AwardCategoryCode
           AND affected.RoleCode = candidate.RoleCode
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO

/* Reject new visible relationships while their source Form is inactive. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockInactiveSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52410, N'Pasif Form kaynağına yayımlanmış aday/kategori eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_BlockInactiveSourceForm
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changed.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52411, N'Pasif Form kaynağı için yayımlanmış jüri oyu eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_BlockInactiveSourceForm
ON dbo.JuryGameTicketFees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52412, N'Pasif Form kaynağı için yayımlanmış bilet ücreti eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_BlockInactiveSourceForm
ON dbo.JuryAssignedPlays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52413, N'Pasif Form kaynağı için yayımlanmış jüri ataması eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_BlockInactiveSourceForm
ON dbo.Blacklist
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52414, N'Pasif Form kaynağı için yayımlanmış blacklist kaydı eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(CreatedAt) OR UPDATE(IsPublished) OR UPDATE(IsActive) OR UPDATE(StatusCode))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.CreatedAt),
        @ToDate = MAX(changed.CreatedAt)
    FROM
    (
        SELECT CreatedAt FROM inserted WHERE CreatedAt IS NOT NULL
        UNION ALL
        SELECT CreatedAt FROM deleted WHERE CreatedAt IS NOT NULL
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshSeasonStatistics
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(CreatedAt) OR UPDATE(IsPublished) OR UPDATE(IsActive))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.CreatedAt),
        @ToDate = MAX(changed.CreatedAt)
    FROM
    (
        SELECT CreatedAt FROM inserted WHERE CreatedAt IS NOT NULL
        UNION ALL
        SELECT CreatedAt FROM deleted WHERE CreatedAt IS NOT NULL
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.RangeDate),
        @ToDate = MAX(changed.RangeDate)
    FROM
    (
        SELECT CONVERT(datetime2(7), SeasonStartDate) AS RangeDate FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonStartDate) FROM deleted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM deleted
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualWrite
ON dbo.Rankings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshAuthorized')) <> 1
       OR SESSION_CONTEXT(N'RankingsRefreshAuthorized') IS NULL
    BEGIN
        THROW 52002,
            N'Rankings can only be changed by dbo.usp_RefreshRankings.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualDelete
ON dbo.Rankings
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52003,
        N'Rankings rows cannot be deleted manually.',
        1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshRankings
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(RecordType) OR UPDATE(IsPublished))
        RETURN;

    EXEC dbo.usp_RefreshRankings;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshRankings
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayId)
           OR UPDATE(AwardCategoryCode)
           OR UPDATE(IsPublished)
           OR UPDATE(IsCurrent)
           OR UPDATE(IsActive)
       )
        RETURN;

    EXEC dbo.usp_RefreshRankings;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshRankings
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayAwardCategoryId)
           OR UPDATE(Score)
           OR UPDATE(IsPublished)
           OR UPDATE(IsActive)
       )
        RETURN;

    EXEC dbo.usp_RefreshRankings;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize
ON dbo.Form
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'FormSeasonAssignmentSyncInProgress')) = 1
    BEGIN
        UPDATE target
        SET SeasonId = changed.SeasonId
        FROM dbo.Form AS target
        INNER JOIN inserted AS changed ON changed.Id = target.Id;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        LEFT JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE previous.Id IS NOT NULL
          AND previous.Id <> changed.Id
    )
        THROW 52404, N'Form.Id oluşturulduktan sonra değiştirilemez.', 1;

    UPDATE target
    SET
        ApplicationNumber = changed.ApplicationNumber,
        SeasonId = season.Id,
        CreatedDate = changed.CreatedDate,
        UpdatedDate = changed.UpdatedDate,
        RepertoireName = changed.RepertoireName,
        TheatreName = changed.TheatreName,
        PremiereDate = changed.PremiereDate,
        Display = changed.Display,
        ApplicantName = changed.ApplicantName,
        ApplicantRole = changed.ApplicantRole,
        Phone = changed.Phone,
        Email = changed.Email,
        Director = changed.Director,
        ContactName = changed.ContactName,
        ContactPhone = changed.ContactPhone,
        LeadActress = changed.LeadActress,
        LeadActor = changed.LeadActor,
        SupportActress = changed.SupportActress,
        SupportActor = changed.SupportActor,
        StageDesign = changed.StageDesign,
        ClothesDesign = changed.ClothesDesign,
        LightDesign = changed.LightDesign,
        StageMusic = changed.StageMusic,
        Choreography = changed.Choreography,
        YoungGenerationArtist = changed.YoungGenerationArtist,
        IsActive = changed.IsActive,
        IsPublished = changed.IsPublished
    FROM dbo.Form AS target
    INNER JOIN inserted AS changed ON changed.Id = target.Id
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, SeasonId, CreatedDate, UpdatedDate,
        RepertoireName, TheatreName, PremiereDate, Display, ApplicantName,
        ApplicantRole, Phone, Email, Director, ContactName, ContactPhone,
        LeadActress, LeadActor, SupportActress, SupportActor, StageDesign,
        ClothesDesign, LightDesign, StageMusic, Choreography,
        YoungGenerationArtist,
        IsActive, IsPublished
    )
    SELECT
        changed.Id, changed.ApplicationNumber, season.Id,
        changed.CreatedDate, changed.UpdatedDate,
        changed.RepertoireName, changed.TheatreName, changed.PremiereDate,
        changed.Display, changed.ApplicantName, changed.ApplicantRole,
        changed.Phone, changed.Email, changed.Director,
        changed.ContactName, changed.ContactPhone,
        changed.LeadActress, changed.LeadActor,
        changed.SupportActress, changed.SupportActor,
        changed.StageDesign, changed.ClothesDesign, changed.LightDesign,
        changed.StageMusic, changed.Choreography,
        changed.YoungGenerationArtist,
        changed.IsActive, changed.IsPublished
    FROM inserted AS changed
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form AS target WHERE target.Id = changed.Id
    );

    EXEC dbo.usp_SynchronizeFormsToPlays;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_ReassignForms
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    EXEC dbo.usp_ReassignFormSeasons;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;

    EXEC dbo.usp_ReassignFormSeasons;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_BlockAdminRecordTypeWithCandidates]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE(column) is true even when a SET clause writes the same value.
    -- Enforce the rule only when RecordType actually changes from Kunye (0)
    -- to Admin (1), leaving both status toggles editable for Kunye plays.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE previousPlay.[RecordType] = 0
          AND currentPlay.[RecordType] = 1
    )
       AND
       (
           EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[PlayAwardCategories] AS candidate
                   ON candidate.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
           OR EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[Blacklist] AS blacklist
                   ON blacklist.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
       )
    BEGIN
        THROW 51212, N'Aday veya blacklist kaydı bulunan bir oyun RecordType 1 olarak değiştirilemez.', 1;
    END;
END;
GO
