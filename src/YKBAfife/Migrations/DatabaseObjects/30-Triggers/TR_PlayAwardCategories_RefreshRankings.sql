CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshRankings
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedCandidates TABLE
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        OldCategoryCode int NULL,
        NewCategoryCode int NULL
    );
    INSERT INTO @ChangedCandidates (Id, OldCategoryCode, NewCategoryCode)
    SELECT COALESCE(currentCandidate.Id, previousCandidate.Id),
           previousCandidate.AwardCategoryCode, currentCandidate.AwardCategoryCode
    FROM inserted AS currentCandidate
    FULL OUTER JOIN deleted AS previousCandidate ON previousCandidate.Id = currentCandidate.Id
    WHERE currentCandidate.Id IS NULL OR previousCandidate.Id IS NULL OR EXISTS
    (
        SELECT currentCandidate.PlayId, currentCandidate.AwardCategoryCode,
               currentCandidate.IsPublished, currentCandidate.IsCurrent, currentCandidate.IsActive
        EXCEPT
        SELECT previousCandidate.PlayId, previousCandidate.AwardCategoryCode,
               previousCandidate.IsPublished, previousCandidate.IsCurrent, previousCandidate.IsActive
    );

    IF NOT EXISTS (SELECT 1 FROM @ChangedCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT CategoryCode FROM
        (
            SELECT OldCategoryCode AS CategoryCode FROM @ChangedCandidates WHERE OldCategoryCode IS NOT NULL
            UNION
            SELECT NewCategoryCode FROM @ChangedCandidates WHERE NewCategoryCode IS NOT NULL
        ) AS affected
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @ChangedCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
