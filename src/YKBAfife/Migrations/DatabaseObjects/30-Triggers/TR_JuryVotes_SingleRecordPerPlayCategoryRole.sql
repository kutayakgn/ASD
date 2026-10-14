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
