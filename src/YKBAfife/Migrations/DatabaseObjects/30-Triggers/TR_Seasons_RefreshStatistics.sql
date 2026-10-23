CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
        WHERE d.Id IS NULL OR EXISTS
            (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
             EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
