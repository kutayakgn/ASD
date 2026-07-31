SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Rankings', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Rankings', N'ConfidenceValue') IS NULL
BEGIN
    ALTER TABLE dbo.Rankings ADD ConfidenceValue int NULL;
END;
GO
BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Rankings', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Rankings
        (
            Id uniqueidentifier NOT NULL
                CONSTRAINT DF_Rankings_Id DEFAULT (NEWSEQUENTIALID()),
            PlayId uniqueidentifier NOT NULL,
            PlayAwardCategoryId uniqueidentifier NOT NULL,
            NumberOfActiveVote int NOT NULL
                CONSTRAINT DF_Rankings_NumberOfActiveVote DEFAULT (0),
            ArithmeticMean float NULL,
            TrimmedMean float NULL,
            ArithmeticRank int NULL,
            TrimmedRank int NULL,
            ArithmeticVariance float NULL,
            ConfidenceValue int NULL,
            IsPublished bit NOT NULL
                CONSTRAINT DF_Rankings_IsPublished DEFAULT (1),
            CONSTRAINT PK_Rankings PRIMARY KEY CLUSTERED (Id),
            CONSTRAINT CK_Rankings_NumberOfActiveVote
                CHECK (NumberOfActiveVote >= 0),
            CONSTRAINT CK_Rankings_ArithmeticRank
                CHECK (ArithmeticRank IS NULL OR ArithmeticRank > 0),
            CONSTRAINT CK_Rankings_TrimmedRank
                CHECK (TrimmedRank IS NULL OR TrimmedRank > 0),
            CONSTRAINT CK_Rankings_ConfidenceValue
                CHECK (ConfidenceValue IS NULL OR ConfidenceValue BETWEEN 1 AND 4)
        );
    END;


    IF COL_LENGTH(N'dbo.Rankings', N'Id') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'PlayId') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'PlayAwardCategoryId') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'NumberOfActiveVote') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'ArithmeticMean') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'TrimmedMean') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'ArithmeticRank') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'TrimmedRank') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'ArithmeticVariance') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'ConfidenceValue') IS NULL
       OR COL_LENGTH(N'dbo.Rankings', N'IsPublished') IS NULL
    BEGIN
        THROW 52000, N'dbo.Rankings exists but does not have the expected schema.', 1;
    END;

    IF OBJECT_ID(N'dbo.CK_Rankings_ConfidenceValue', N'C') IS NULL
    BEGIN
        ALTER TABLE dbo.Rankings WITH CHECK
            ADD CONSTRAINT CK_Rankings_ConfidenceValue
            CHECK (ConfidenceValue IS NULL OR ConfidenceValue BETWEEN 1 AND 4);
    END;

    IF OBJECT_ID(N'dbo.FK_Rankings_Plays', N'F') IS NULL
    BEGIN
        ALTER TABLE dbo.Rankings WITH CHECK
            ADD CONSTRAINT FK_Rankings_Plays
            FOREIGN KEY (PlayId) REFERENCES dbo.Plays (Id)
            ON UPDATE NO ACTION ON DELETE NO ACTION;
    END;

    IF OBJECT_ID(N'dbo.FK_Rankings_PlayAwardCategories', N'F') IS NULL
    BEGIN
        ALTER TABLE dbo.Rankings WITH CHECK
            ADD CONSTRAINT FK_Rankings_PlayAwardCategories
            FOREIGN KEY (PlayAwardCategoryId)
            REFERENCES dbo.PlayAwardCategories (Id)
            ON UPDATE NO ACTION ON DELETE NO ACTION;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Rankings')
          AND name = N'UX_Rankings_PlayAwardCategoryId'
    )
    BEGIN
        CREATE UNIQUE INDEX UX_Rankings_PlayAwardCategoryId
            ON dbo.Rankings (PlayAwardCategoryId);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Rankings')
          AND name = N'IX_Rankings_PlayId_IsPublished'
    )
    BEGIN
        CREATE INDEX IX_Rankings_PlayId_IsPublished
            ON dbo.Rankings (PlayId, IsPublished)
            INCLUDE
            (
                PlayAwardCategoryId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                ArithmeticRank,
                TrimmedRank,
                ArithmeticVariance,
                ConfidenceValue
            );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.JuryVotes')
          AND name = N'IX_JuryVotes_RankingProjection'
    )
    BEGIN
        CREATE INDEX IX_JuryVotes_RankingProjection
            ON dbo.JuryVotes (PlayAwardCategoryId, IsPublished, IsActive)
            INCLUDE (Score, Id);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshRankings
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

DENY INSERT, UPDATE, DELETE ON dbo.Rankings TO public;
GRANT SELECT ON dbo.Rankings TO public;
GRANT EXECUTE ON dbo.usp_RefreshRankings TO public;
GO

EXEC dbo.usp_RefreshRankings;
GO

SELECT
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
FROM dbo.Rankings
WHERE IsPublished = 1
ORDER BY ArithmeticRank, TrimmedRank, PlayAwardCategoryId;
GO
