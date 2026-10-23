CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY, EligibilityChanged bit NOT NULL);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id),
        CASE WHEN i.Id IS NULL OR d.Id IS NULL OR EXISTS
            (SELECT i.IsPublished, i.IsActive EXCEPT SELECT d.IsPublished, d.IsActive) THEN 1 ELSE 0 END
    FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.StatusCode
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.StatusCode);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
            /* A play and its votes may belong to different calendar seasons. */
            UNION SELECT vote.CreatedAt FROM @Changed c
            INNER JOIN dbo.PlayAwardCategories candidate ON candidate.PlayId = c.Id
            INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = candidate.Id
            WHERE c.EligibilityChanged = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
