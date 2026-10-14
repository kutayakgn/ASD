CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSourceForm
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    IF NOT
       (
           UPDATE(PlayName) OR UPDATE(TheaterName) OR UPDATE(Phone)
           OR UPDATE(ContactPersonName) OR UPDATE(ContactPersonPhone)
           OR UPDATE(Email) OR UPDATE(IsActive) OR UPDATE(IsPublished)
       )
        RETURN;

    DECLARE @AffectedPlayId uniqueidentifier;
    DECLARE affected_play_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT changed.Id
        FROM inserted AS changed
        WHERE changed.SourceFormId IS NOT NULL;

    OPEN affected_play_cursor;
    FETCH NEXT FROM affected_play_cursor INTO @AffectedPlayId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_SynchronizePlayDataToForms @PlayId = @AffectedPlayId;
        FETCH NEXT FROM affected_play_cursor INTO @AffectedPlayId;
    END;
    CLOSE affected_play_cursor;
    DEALLOCATE affected_play_cursor;
END;
