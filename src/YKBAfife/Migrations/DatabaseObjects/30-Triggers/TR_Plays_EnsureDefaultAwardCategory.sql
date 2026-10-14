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
        defaultCategory.IsPublished = CASE
            WHEN currentPlay.IsPublished = 1
             AND currentPlay.IsActive = 1
             AND
             (
                 currentPlay.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        defaultCategory.IsActive = CASE
            WHEN currentPlay.IsPublished = 1
             AND currentPlay.IsActive = 1
             AND
             (
                 currentPlay.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = currentPlay.SourceFormId
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND
      (
          currentPlay.TheaterName <> previousPlay.TheaterName
          OR defaultCategory.Candidate <> currentPlay.TheaterName
          OR ISNULL(defaultCategory.Role, N'') <> N'Tiyatro'
          OR defaultCategory.IsPublished <> CASE
              WHEN currentPlay.IsPublished = 1
               AND currentPlay.IsActive = 1
               AND
               (
                   currentPlay.SourceFormId IS NULL
                   OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
               ) THEN 1 ELSE 0 END
          OR defaultCategory.IsActive <> CASE
              WHEN currentPlay.IsPublished = 1
               AND currentPlay.IsActive = 1
               AND
               (
                   currentPlay.SourceFormId IS NULL
                   OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
               ) THEN 1 ELSE 0 END
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
