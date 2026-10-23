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

    DECLARE @AffectedPlayIdsJson nvarchar(max) =
    (
        SELECT changed.Id
        FROM inserted AS changed
        INNER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE changed.SourceFormId IS NOT NULL
          AND EXISTS
          (
              SELECT CONVERT(varbinary(max), changed.PlayName),
                     CONVERT(varbinary(max), changed.TheaterName),
                     CONVERT(varbinary(max), changed.Phone),
                     CONVERT(varbinary(max), changed.ContactPersonName),
                     CONVERT(varbinary(max), changed.ContactPersonPhone),
                     CONVERT(varbinary(max), changed.Email),
                     changed.IsActive, changed.IsPublished
              EXCEPT
              SELECT CONVERT(varbinary(max), previous.PlayName),
                     CONVERT(varbinary(max), previous.TheaterName),
                     CONVERT(varbinary(max), previous.Phone),
                     CONVERT(varbinary(max), previous.ContactPersonName),
                     CONVERT(varbinary(max), previous.ContactPersonPhone),
                     CONVERT(varbinary(max), previous.Email),
                     previous.IsActive, previous.IsPublished
          )
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; NULL is the procedure's
       explicit full-maintenance API and must never come from an empty trigger. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 0;
END;
