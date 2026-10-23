CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshRankings]
    @CategoryCodesJson nvarchar(max) = NULL,
    @CandidateIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshInProgress')) = 1
        RETURN;

    /* Explicit maintenance keeps the historical full-rebuild contract. Normal
       DML supplies old/new categories and dirty candidate IDs. Rankings depend
       on peers in the same category, but their unchanged votes need no reread. */
    DECLARE @FullRefresh bit = CASE WHEN @CategoryCodesJson IS NULL THEN 1 ELSE 0 END;
    CREATE TABLE #RankingAffectedCategories (CategoryCode int NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingDirtyCandidates (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingCategoryLocks
    (
        CategoryCode int NOT NULL PRIMARY KEY,
        IsAcquired bit NOT NULL DEFAULT (0)
    );

    IF @CategoryCodesJson IS NULL AND @CandidateIdsJson IS NOT NULL
        THROW 52740, N'Aday kapsamı için ödül kategorisi kapsamı da gereklidir.', 1;

    IF @CategoryCodesJson IS NOT NULL
    BEGIN
        IF ISJSON(@CategoryCodesJson) <> 1 OR LEFT(LTRIM(@CategoryCodesJson), 1) <> N'['
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CategoryCodesJson) AS item
            WHERE item.[type] <> 5 OR TRY_CONVERT(int,
                JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.CategoryCode')) IS NULL
        )
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        INSERT INTO #RankingAffectedCategories (CategoryCode)
        SELECT DISTINCT CONVERT(int, JSON_VALUE(item.[value], N'$.CategoryCode'))
        FROM OPENJSON(@CategoryCodesJson) AS item;
    END;

    IF @CandidateIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@CandidateIdsJson) <> 1 OR LEFT(LTRIM(@CandidateIdsJson), 1) <> N'['
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CandidateIdsJson) AS item
            WHERE item.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        INSERT INTO #RankingDirtyCandidates (CandidateId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(item.[value], N'$.Id'))
        FROM OPENJSON(@CandidateIdsJson) AS item;
    END;

    IF @FullRefresh = 0
       AND NOT EXISTS (SELECT 1 FROM #RankingAffectedCategories)
       AND NOT EXISTS (SELECT 1 FROM #RankingDirtyCandidates)
        RETURN;

    DECLARE @ApplicationLockResult int;
    DECLARE @GlobalLockMode nvarchar(32) = CASE WHEN @FullRefresh = 1 THEN N'Exclusive' ELSE N'Shared' END;
    DECLARE @LockedCategory int;
    DECLARE @CategoryLockResource nvarchar(255);
    /* Scalar variables survive a deadlock victim's transaction rollback. A
       temp-table acquisition log does not, while session-owned locks survive. */
    DECLARE @AcquiredCategoryLocks nvarchar(max) = N'';
    DECLARE @CategoryLockDelimiter int;
    EXEC @ApplicationLockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Rankings.Refresh',
        @LockMode = @GlobalLockMode,
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
        IF @FullRefresh = 1
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT AwardCategoryCode FROM dbo.PlayAwardCategories;
        ELSE
            /* A moved dirty candidate brings its new category even if a caller
               only supplied its previous category. */
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT candidate.AwardCategoryCode
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = candidate.Id
            WHERE NOT EXISTS
            (
                SELECT 1 FROM #RankingAffectedCategories AS affected
                WHERE affected.CategoryCode = candidate.AwardCategoryCode
            );

        /* Different categories can refresh concurrently. Full maintenance takes
           the global lock exclusively; scoped callers share it and acquire all
           their category locks in numeric order, including both sides of moves. */
        IF @FullRefresh = 0
        BEGIN
            INSERT INTO #RankingCategoryLocks (CategoryCode)
            SELECT CategoryCode FROM #RankingAffectedCategories;
            WHILE EXISTS (SELECT 1 FROM #RankingCategoryLocks WHERE IsAcquired = 0)
            BEGIN
                SELECT TOP (1) @LockedCategory = CategoryCode
                FROM #RankingCategoryLocks WHERE IsAcquired = 0 ORDER BY CategoryCode;
                SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
                EXEC @ApplicationLockResult = sys.sp_getapplock
                    @Resource = @CategoryLockResource, @LockMode = N'Exclusive',
                    @LockOwner = N'Session', @LockTimeout = 30000;
                IF @ApplicationLockResult < 0
                    THROW 52001, N'Rankings category refresh lock could not be acquired.', 1;
                SET @AcquiredCategoryLocks += CONVERT(nvarchar(12), @LockedCategory) + N';';
                UPDATE #RankingCategoryLocks SET IsAcquired = 1 WHERE CategoryCode = @LockedCategory;
            END;
        END;

        CREATE TABLE #RankingTargetScope (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingTargetScope (CandidateId)
        SELECT candidate.Id
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        UNION
        SELECT CandidateId FROM #RankingDirtyCandidates
        UNION
        SELECT PlayAwardCategoryId FROM dbo.Rankings WHERE @FullRefresh = 1;

        CREATE TABLE #RankingEligibleCandidates
        (
            PlayAwardCategoryId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL
        );
        INSERT INTO #RankingEligibleCandidates (PlayAwardCategoryId, PlayId, AwardCategoryCode)
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE play.RecordType = 0 AND play.IsPublished = 1 AND play.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsCurrent = 1 AND candidate.IsActive = 1;

        CREATE TABLE #RankingRecalculate (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingRecalculate (CandidateId)
        SELECT eligible.PlayAwardCategoryId
        FROM #RankingEligibleCandidates AS eligible
        LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
        LEFT JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
        WHERE @CandidateIdsJson IS NULL OR dirty.CandidateId IS NOT NULL
           OR previous.Id IS NULL OR previous.IsPublished = 0;

        ;WITH OrderedActiveVotes AS
        (
            SELECT
                dirty.CandidateId AS PlayAwardCategoryId,
                vote.Score,
                ROW_NUMBER() OVER
                (
                    PARTITION BY dirty.CandidateId
                    ORDER BY vote.Score, vote.Id
                ) AS ScoreOrder,
                COUNT_BIG(*) OVER
                (
                    PARTITION BY dirty.CandidateId
                ) AS VoteCount
            FROM #RankingRecalculate AS dirty
            INNER JOIN dbo.JuryVotes AS vote
                ON vote.PlayAwardCategoryId = dirty.CandidateId
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
                CASE WHEN dirty.CandidateId IS NOT NULL
                    THEN CONVERT(int, COALESCE(voteStats.NumberOfActiveVote, 0))
                    ELSE previous.NumberOfActiveVote END
                    AS NumberOfActiveVote,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticMean ELSE previous.ArithmeticMean END AS ArithmeticMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN trimmed.TrimmedMean ELSE previous.TrimmedMean END AS TrimmedMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticVariance ELSE previous.ArithmeticVariance END AS ArithmeticVariance
            FROM #RankingEligibleCandidates AS eligible
            LEFT JOIN #RankingRecalculate AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
            LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
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
            );

        /* Restrict retirement separately: a partial source must never unpublish
           rankings from other categories. Dirty IDs also cover removed rows. */
        UPDATE target
        SET IsPublished = 0
        FROM dbo.Rankings AS target
        INNER JOIN #RankingTargetScope AS affected ON affected.CandidateId = target.PlayAwardCategoryId
        LEFT JOIN #RankingEligibleCandidates AS eligible ON eligible.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHERE target.IsPublished = 1 AND eligible.PlayAwardCategoryId IS NULL;

        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshAuthorized',
            @value = NULL;
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshInProgress',
            @value = NULL;
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
        END;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Rankings.Refresh',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        BEGIN TRY
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = NULL;
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = NULL;
        END TRY
        BEGIN CATCH
            PRINT N'Rankings session-context cleanup failed.';
        END CATCH;
        /* No temp-table access here: SQL 1205 can remove those tables. Cleanup
           failures must not prevent release of other locks or mask the error. */
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            BEGIN TRY
                EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            END TRY
            BEGIN CATCH
                PRINT N'Rankings category-lock cleanup failed.';
            END CATCH;
        END;
        BEGIN TRY
            EXEC sys.sp_releaseapplock @Resource = N'AfifeAdmin.Rankings.Refresh', @LockOwner = N'Session';
        END TRY
        BEGIN CATCH
            PRINT N'Rankings global-lock cleanup failed.';
        END CATCH;
        THROW;
    END CATCH;
END;
