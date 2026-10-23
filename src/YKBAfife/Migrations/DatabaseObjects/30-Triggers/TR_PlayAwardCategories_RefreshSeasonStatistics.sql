CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshSeasonStatistics
ON dbo.PlayAwardCategories AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id
        FROM inserted i INNER JOIN deleted d ON d.Id = i.Id
        INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = i.Id
        INNER JOIN dbo.Seasons season
            ON vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
           AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
          AND EXISTS (SELECT i.PlayId, i.IsPublished, i.IsActive
                      EXCEPT SELECT d.PlayId, d.IsPublished, d.IsActive)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
