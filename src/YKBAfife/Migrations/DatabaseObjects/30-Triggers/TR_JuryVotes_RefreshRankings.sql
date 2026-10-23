CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshRankings
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    ;WITH ChangedVotes AS
    (
        SELECT currentVote.PlayAwardCategoryId AS NewCandidateId,
               previousVote.PlayAwardCategoryId AS OldCandidateId
        FROM inserted AS currentVote
        FULL OUTER JOIN deleted AS previousVote ON previousVote.Id = currentVote.Id
        WHERE currentVote.Id IS NULL OR previousVote.Id IS NULL OR EXISTS
        (
            SELECT currentVote.PlayAwardCategoryId, currentVote.Score, currentVote.IsPublished, currentVote.IsActive
            EXCEPT
            SELECT previousVote.PlayAwardCategoryId, previousVote.Score, previousVote.IsPublished, previousVote.IsActive
        )
    )
    INSERT INTO @DirtyCandidates (Id)
    SELECT NewCandidateId FROM ChangedVotes WHERE NewCandidateId IS NOT NULL
    UNION
    SELECT OldCandidateId FROM ChangedVotes WHERE OldCandidateId IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT DISTINCT candidate.AwardCategoryCode AS CategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN @DirtyCandidates AS dirty ON dirty.Id = candidate.Id
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
