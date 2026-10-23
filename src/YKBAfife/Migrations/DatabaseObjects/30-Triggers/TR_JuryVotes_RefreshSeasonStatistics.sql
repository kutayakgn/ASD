CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshSeasonStatistics
ON dbo.JuryVotes AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id) FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.PlayAwardCategoryId
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.PlayAwardCategoryId);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
