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

    DECLARE @AffectedPlayIdsJson nvarchar(max);
    ;WITH ChangedCandidates AS
    (
        SELECT changed.PlayId AS NewPlayId, previous.PlayId AS OldPlayId
        FROM inserted AS changed
        FULL OUTER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE (changed.AwardCategoryCode BETWEEN 1002 AND 1011
               OR previous.AwardCategoryCode BETWEEN 1002 AND 1011)
          AND
          (
              changed.Id IS NULL OR previous.Id IS NULL
              OR EXISTS
              (
                  SELECT changed.PlayId, changed.AwardCategoryCode,
                         CONVERT(varbinary(max), changed.Candidate),
                         CONVERT(varbinary(max), changed.Role), changed.PhotoImageId,
                         changed.IsPublished, changed.IsCurrent
                  EXCEPT
                  SELECT previous.PlayId, previous.AwardCategoryCode,
                         CONVERT(varbinary(max), previous.Candidate),
                         CONVERT(varbinary(max), previous.Role), previous.PhotoImageId,
                         previous.IsPublished, previous.IsCurrent
              )
          )
    ), AffectedPlays AS
    (
        SELECT NewPlayId AS PlayId FROM ChangedCandidates WHERE NewPlayId IS NOT NULL
        UNION
        SELECT OldPlayId FROM ChangedCandidates WHERE OldPlayId IS NOT NULL
    )
    SELECT @AffectedPlayIdsJson =
    (
        SELECT play.Id
        FROM dbo.Plays AS play
        INNER JOIN AffectedPlays AS affected ON affected.PlayId = play.Id
        WHERE play.SourceFormId IS NOT NULL
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; never expand a no-op DML
       statement into the procedure's NULL/full-maintenance scope. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 1;
END;
