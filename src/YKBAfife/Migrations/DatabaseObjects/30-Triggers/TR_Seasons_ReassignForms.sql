CREATE OR ALTER TRIGGER dbo.TR_Seasons_ReassignForms
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1 RETURN;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
    WHERE d.Id IS NULL OR EXISTS
        (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
         EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @ChangedSeasonsJson nvarchar(max) =
    (
        SELECT ranges.Id, ranges.SeasonStartDate AS StartDate, ranges.SeasonEndDate AS EndDate
        FROM
        (
            SELECT i.Id, i.SeasonStartDate, i.SeasonEndDate FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.Id, d.SeasonStartDate, d.SeasonEndDate FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) ranges FOR JSON PATH
    );
    EXEC dbo.usp_ReassignFormSeasons @ChangedSeasonsJson = @ChangedSeasonsJson;
END;
