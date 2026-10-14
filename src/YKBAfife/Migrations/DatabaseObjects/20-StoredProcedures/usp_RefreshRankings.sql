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
