CREATE OR ALTER TRIGGER dbo.TR_Plays_EnsureDefaultAwardCategory
ON dbo.Plays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE defaultCategory
    SET
        defaultCategory.Candidate = currentPlay.TheaterName,
        defaultCategory.Role = N'Tiyatro',
        defaultCategory.IsPublished = expected.IsPublished,
        defaultCategory.IsActive = CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
            WHEN expected.IsPublished = 0 THEN 0
            WHEN defaultCategory.IsPublished = 0 THEN 1
            ELSE defaultCategory.IsActive END,
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = currentPlay.SourceFormId
    CROSS APPLY
    (
        SELECT CONVERT(bit, CASE
            WHEN TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
                THEN 1 ELSE 0 END) AS IsSynchronizing
    ) AS lifecycle
    CROSS APPLY
    (
        /* Form lifecycle captures the current flags before deactivation and
           restores them explicitly. Metadata updates must not overwrite that
           snapshot or a manually disabled default candidate. */
        SELECT CONVERT(bit, CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsPublished
            WHEN currentPlay.IsPublished = 1
             AND currentPlay.IsActive = 1
             AND
             (
                 currentPlay.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END) AS IsPublished
    ) AS expected
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND
      (
          currentPlay.TheaterName <> previousPlay.TheaterName
          OR defaultCategory.Candidate <> currentPlay.TheaterName
          OR ISNULL(defaultCategory.Role, N'') <> N'Tiyatro'
          OR defaultCategory.IsPublished <> expected.IsPublished
          OR defaultCategory.IsActive <> CASE
              WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
              WHEN expected.IsPublished = 0 THEN 0
              WHEN defaultCategory.IsPublished = 0 THEN 1
              ELSE defaultCategory.IsActive END
      );

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, IsActive,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        play.TheaterName,
        1001,
        1,
        N'Tiyatro',
        0,
        NULL
    FROM inserted AS play
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );
END;
