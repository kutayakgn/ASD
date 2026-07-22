SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL OR
   OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
    THROW 51130, 'PlayAwardCategories or JuryVotes table was not found.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- IsPublished becomes the only candidate publication/status field. Preserve
    -- every previously inactive candidate by making it unpublished before drop.
    IF COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql N'
            UPDATE dbo.PlayAwardCategories
            SET IsPublished = 0,
                UpdatedAt = COALESCE(UpdatedAt, SYSUTCDATETIME())
            WHERE IsActive = 0
              AND IsPublished = 1;';

        DECLARE @DefaultConstraint sysname;
        SELECT @DefaultConstraint = defaultConstraint.name
        FROM sys.default_constraints AS defaultConstraint
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.object_id = defaultConstraint.parent_object_id
           AND columnInfo.column_id = defaultConstraint.parent_column_id
        WHERE defaultConstraint.parent_object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
          AND columnInfo.name = N'IsActive';

        IF @DefaultConstraint IS NOT NULL
        BEGIN
            DECLARE @DropDefaultSql nvarchar(max) =
                N'ALTER TABLE dbo.PlayAwardCategories DROP CONSTRAINT '
                + QUOTENAME(@DefaultConstraint) + N';';
            EXEC sys.sp_executesql @DropDefaultSql;
        END;

        EXEC(N'ALTER TABLE dbo.PlayAwardCategories DROP COLUMN IsActive;');
    END;

    -- The logical vote identity is Jury + Play + Category + Role. If legacy data
    -- contains old/new candidate vote rows together, keep only the latest row.
    ;WITH RankedVotes AS
    (
        SELECT
            vote.Id,
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    vote.JuryId,
                    candidate.PlayId,
                    candidate.AwardCategoryCode,
                    candidate.RoleCode
                ORDER BY
                    COALESCE(vote.UpdatedAt, vote.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    vote.Id DESC
            ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
    )
    DELETE vote
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;


    -- Deleting a candidate is an explicit hard-delete operation. Its dependent
    -- JuryVotes rows must be deleted by the database in the same transaction.
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
    BEGIN
        DECLARE @DropCandidateVoteForeignKeySql nvarchar(max) =
            N'ALTER TABLE dbo.JuryVotes DROP CONSTRAINT '
            + QUOTENAME(@CandidateVoteForeignKey) + N';';
        EXEC sys.sp_executesql @DropCandidateVoteForeignKeySql;
    END;

    ALTER TABLE dbo.JuryVotes WITH CHECK
        ADD CONSTRAINT FK_JuryVotes_PlayAwardCategories
        FOREIGN KEY (PlayAwardCategoryId)
        REFERENCES dbo.PlayAwardCategories (Id)
        ON UPDATE CASCADE
        ON DELETE CASCADE;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

DROP TRIGGER IF EXISTS dbo.TR_JuryVotes_SinglePublishedPerPlayCategoryRole;
DROP TRIGGER IF EXISTS dbo.TR_PlayAwardCategories_NormalizePublishedJuryVotes;
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
                PARTITION BY
                    changedVote.JuryId,
                    candidate.PlayId,
                    candidate.AwardCategoryCode,
                    candidate.RoleCode
                ORDER BY
                    COALESCE(changedVote.UpdatedAt, changedVote.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    changedVote.Id DESC
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

    -- Lock candidate rows for each logical group so shared applications cannot
    -- concurrently leave two physical JuryVotes records in the same group.
    DECLARE @LockedCandidateCount bigint;
    SELECT @LockedCandidateCount = COUNT_BIG(*)
    FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN @AffectedGroups AS affected
        ON affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode;

    -- A vote may be preserved for an unpublished candidate, but it can never be
    -- calculation-eligible while that candidate remains unpublished.
    UPDATE vote
    SET
        vote.IsPublished = 0,
        vote.UpdatedAt = SYSUTCDATETIME()
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE candidate.IsPublished = 0
      AND vote.IsPublished = 1;

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

    -- Candidate publication controls vote calculation eligibility in both
    -- directions. Hard deletion is handled separately by ON DELETE CASCADE.
    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET
            vote.IsPublished = candidate.IsPublished,
            vote.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate
            ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND vote.IsPublished <> candidate.IsPublished;
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    -- Moving a candidate can merge two logical groups. Keep the newest physical
    -- vote row for each jury in every affected old/new group and delete the rest.
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
                PARTITION BY
                    vote.JuryId,
                    candidate.PlayId,
                    candidate.AwardCategoryCode,
                    candidate.RoleCode
                ORDER BY
                    COALESCE(vote.UpdatedAt, vote.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    vote.Id DESC
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

-- Both verification queries must return zero rows.
SELECT
    vote.JuryId,
    candidate.PlayId,
    candidate.AwardCategoryCode,
    candidate.RoleCode,
    COUNT_BIG(*) AS VoteRecordCount
FROM dbo.JuryVotes AS vote
INNER JOIN dbo.PlayAwardCategories AS candidate
    ON candidate.Id = vote.PlayAwardCategoryId
GROUP BY
    vote.JuryId,
    candidate.PlayId,
    candidate.AwardCategoryCode,
    candidate.RoleCode
HAVING COUNT_BIG(*) > 1;

SELECT COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') AS IsActiveColumnLength;
