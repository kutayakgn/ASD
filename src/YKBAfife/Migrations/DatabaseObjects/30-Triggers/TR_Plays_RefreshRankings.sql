CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshRankings
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedPlays TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    INSERT INTO @ChangedPlays (Id)
    SELECT COALESCE(currentPlay.Id, previousPlay.Id)
    FROM inserted AS currentPlay
    FULL OUTER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    WHERE currentPlay.Id IS NULL OR previousPlay.Id IS NULL OR EXISTS
    (
        SELECT currentPlay.RecordType, currentPlay.IsPublished, currentPlay.IsActive
        EXCEPT
        SELECT previousPlay.RecordType, previousPlay.IsPublished, previousPlay.IsActive
    );

    /* Eligibility changes affect every candidate on these plays, including a
       direct IsActive toggle. Pure metadata edits leave ranking metrics alone. */
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY, CategoryCode int NOT NULL);
    INSERT INTO @DirtyCandidates (Id, CategoryCode)
    SELECT candidate.Id, candidate.AwardCategoryCode
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN @ChangedPlays AS affected ON affected.Id = candidate.PlayId;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) =
        COALESCE((SELECT DISTINCT CategoryCode FROM @DirtyCandidates FOR JSON PATH), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
