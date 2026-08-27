CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* 1001 is generated automatically immediately after a Play insert. It has
       no Form candidate JSON field and must never clear the imported arrays. */
    IF NOT EXISTS
    (
        SELECT 1 FROM inserted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
        UNION ALL
        SELECT 1 FROM deleted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
    )
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayId) OR UPDATE(Candidate) OR UPDATE(Role)
           OR UPDATE(PhotoImageId) OR UPDATE(AwardCategoryCode)
           OR UPDATE(IsPublished) OR UPDATE(IsCurrent)
       )
        RETURN;

    DECLARE @AffectedPlayId uniqueidentifier;
    DECLARE affected_candidate_play_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT affected.PlayId
        FROM
        (
            SELECT PlayId FROM inserted
            UNION
            SELECT PlayId FROM deleted
        ) AS affected
        INNER JOIN dbo.Plays AS play ON play.Id = affected.PlayId
        WHERE play.SourceFormId IS NOT NULL;

    OPEN affected_candidate_play_cursor;
    FETCH NEXT FROM affected_candidate_play_cursor INTO @AffectedPlayId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_SynchronizePlayDataToForms @PlayId = @AffectedPlayId;
        FETCH NEXT FROM affected_candidate_play_cursor INTO @AffectedPlayId;
    END;
    CLOSE affected_candidate_play_cursor;
    DEALLOCATE affected_candidate_play_cursor;
END;
