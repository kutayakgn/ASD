DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
DECLARE @RetiredImageIds TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);

INSERT INTO @RetiredImageIds (Id)
SELECT DISTINCT PhotoImageId
FROM dbo.PlayAwardCategories
WHERE AwardCategoryCode = 1012
  AND PhotoImageId IS NOT NULL;

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = 1;

BEGIN TRY
    /* Preserve historical rows while retiring the removed 1012 category. */
    UPDATE vote
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE candidate.AwardCategoryCode = 1012
      AND (vote.IsPublished = 1 OR vote.IsActive = 1);

    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    WHERE candidate.AwardCategoryCode = 1012
      AND
      (
          candidate.IsPublished = 1
          OR candidate.IsActive = 1
          OR candidate.IsCurrent = 1
      );

    /* Normalize votes/candidates belonging to inactive Form sources. */
    UPDATE vote
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE (vote.IsPublished = 1 OR vote.IsActive = 1)
      AND
      (
          formRecord.IsPublished = 0
          OR formRecord.IsActive = 0
          OR play.IsPublished = 0
          OR play.IsActive = 0
      );

    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE (candidate.IsPublished = 1 OR candidate.IsActive = 1)
      AND
      (
          formRecord.IsPublished = 0
          OR formRecord.IsActive = 0
          OR play.IsPublished = 0
          OR play.IsActive = 0
      );

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = NULL;
END TRY
BEGIN CATCH
    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = NULL;
    THROW;
END CATCH;

UPDATE image
SET IsPublished = 0,
    UpdatedAt = @Now
FROM dbo.Images AS image
INNER JOIN @RetiredImageIds AS retired ON retired.Id = image.Id
WHERE image.IsPublished = 1
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.PlayAwardCategories AS candidate
      WHERE candidate.PhotoImageId = image.Id
        AND candidate.IsPublished = 1
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.Users AS appUser
      WHERE appUser.PhotoImageId = image.Id
        AND appUser.IsPublished = 1
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.Announcements AS announcement
      WHERE (announcement.ImageId = image.Id
             OR announcement.BackgroundImageId = image.Id)
        AND announcement.IsPublished = 1
  );

/* Re-fire the canonical default-category trigger only where state differs. */
UPDATE play
SET UpdatedAt = @Now
FROM dbo.Plays AS play
LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
OUTER APPLY
(
    SELECT TOP (1) candidate.IsPublished, candidate.IsActive
    FROM dbo.PlayAwardCategories AS candidate
    WHERE candidate.PlayId = play.Id
      AND candidate.AwardCategoryCode = 1001
      AND candidate.RoleCode = 0
    ORDER BY candidate.IsCurrent DESC, candidate.Id
) AS defaultCandidate
CROSS APPLY
(
    SELECT CONVERT(bit, CASE
        WHEN play.IsPublished = 1
         AND play.IsActive = 1
         AND
         (
             play.SourceFormId IS NULL
             OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
         ) THEN 1 ELSE 0 END) AS ShouldBeVisible
) AS expected
WHERE play.RecordType = 0
  AND
  (
      defaultCandidate.IsPublished IS NULL
      OR defaultCandidate.IsPublished <> expected.ShouldBeVisible
      OR defaultCandidate.IsActive <> expected.ShouldBeVisible
  );
