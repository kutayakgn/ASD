USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
BEGIN
    THROW 51500, N'PlayAwardCategories veya JuryVotes tablosu bulunamadi.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') IS NULL
    BEGIN
        ALTER TABLE dbo.PlayAwardCategories
            ADD IsActive bit NOT NULL
                CONSTRAINT DF_PlayAwardCategories_IsActive DEFAULT (1) WITH VALUES;

        -- Before this migration IsPublished represented candidate activity.
        EXEC sys.sp_executesql N'
            UPDATE dbo.PlayAwardCategories
            SET IsActive = IsPublished,
                IsPublished = 1;';
    END;

    IF COL_LENGTH(N'dbo.JuryVotes', N'IsActive') IS NULL
    BEGIN
        ALTER TABLE dbo.JuryVotes
            ADD IsActive bit NOT NULL
                CONSTRAINT DF_JuryVotes_IsActive DEFAULT (1) WITH VALUES;

        -- Preserve the former calculation state while making existing rows non-deleted.
        EXEC sys.sp_executesql N'
            UPDATE dbo.JuryVotes
            SET IsActive = IsPublished,
                IsPublished = 1;';
    END;

    -- Normalize legacy duplicates before enabling the one-vote-per-logical-role trigger.
    ;WITH RankedVotes AS
    (
        SELECT
            vote.Id,
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
    )
    DELETE vote
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;

    -- A physical candidate delete is exceptional, but when it occurs its votes
    -- must be removed atomically. UI delete operations remain soft deletes.
    DECLARE @CandidateVoteForeignKey sysname;
    SELECT TOP (1) @CandidateVoteForeignKey = foreignKey.name
    FROM sys.foreign_keys AS foreignKey
    INNER JOIN sys.foreign_key_columns AS foreignKeyColumn
        ON foreignKeyColumn.constraint_object_id = foreignKey.object_id
    INNER JOIN sys.columns AS parentColumn
        ON parentColumn.object_id = foreignKeyColumn.parent_object_id
       AND parentColumn.column_id = foreignKeyColumn.parent_column_id
    WHERE foreignKey.parent_object_id = OBJECT_ID(N'dbo.JuryVotes')
      AND foreignKey.referenced_object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND parentColumn.name = N'PlayAwardCategoryId';

    IF @CandidateVoteForeignKey IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM sys.foreign_keys
           WHERE name = @CandidateVoteForeignKey
             AND delete_referential_action = 1
             AND update_referential_action = 1
       )
    BEGIN
        DECLARE @DropCandidateVoteForeignKeySql nvarchar(max);
        SET @DropCandidateVoteForeignKeySql =
            N'ALTER TABLE dbo.JuryVotes DROP CONSTRAINT ['
            + REPLACE(@CandidateVoteForeignKey, N']', N']]') + N'];';
        EXEC sys.sp_executesql @DropCandidateVoteForeignKeySql;
        SET @CandidateVoteForeignKey = NULL;
    END;

    IF @CandidateVoteForeignKey IS NULL
    BEGIN
        ALTER TABLE dbo.JuryVotes WITH CHECK
            ADD CONSTRAINT FK_JuryVotes_PlayAwardCategories
            FOREIGN KEY (PlayAwardCategoryId)
            REFERENCES dbo.PlayAwardCategories (Id)
            ON UPDATE CASCADE
            ON DELETE CASCADE;
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

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
    )
    INSERT INTO @AffectedGroups
        (JuryId, PlayId, AwardCategoryCode, RoleCode, WinnerVoteId)
    SELECT JuryId, PlayId, AwardCategoryCode, RoleCode, Id
    FROM ChangedVotes
    WHERE VoteOrder = 1;

    DECLARE @LockedCandidateCount bigint;
    SELECT @LockedCandidateCount = COUNT_BIG(*)
    FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN @AffectedGroups AS affected
        ON affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode;

    UPDATE vote
    SET
        vote.IsPublished = CASE WHEN candidate.IsPublished = 0 THEN 0 ELSE vote.IsPublished END,
        vote.IsActive = CASE WHEN candidate.IsActive = 0 THEN 0 ELSE vote.IsActive END,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE (candidate.IsPublished = 0 AND vote.IsPublished = 1)
       OR (candidate.IsActive = 0 AND vote.IsActive = 1);

    DELETE vote
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN @AffectedGroups AS affected
        ON affected.JuryId = vote.JuryId
       AND affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode
    WHERE vote.Id <> affected.WinnerVoteId;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET
            vote.IsActive = candidate.IsActive,
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
        SET
            vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive
                ELSE vote.IsActive
            END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR (candidate.IsPublished = 1 AND vote.IsActive <> candidate.IsActive)
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
        SELECT
            vote.Id,
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
    )
    DELETE vote
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO

SELECT
    COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') AS CandidateIsActiveColumn,
    COL_LENGTH(N'dbo.JuryVotes', N'IsActive') AS VoteIsActiveColumn;
GO