SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

BEGIN TRANSACTION;

DECLARE @CandidateId uniqueidentifier;
DECLARE @PlayId uniqueidentifier;

SELECT TOP (1)
    @CandidateId = candidate.Id,
    @PlayId = play.Id
FROM dbo.PlayAwardCategories AS candidate
INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
WHERE candidate.AwardCategoryCode = 1002
  AND candidate.IsPublished = 1
  AND candidate.IsActive = 1
  AND play.IsPublished = 1
  AND play.IsActive = 1
  AND formRecord.IsPublished = 1
  AND formRecord.IsActive = 1
ORDER BY candidate.Id;

IF @CandidateId IS NULL
    THROW 52993, N'Pasif Form yönetmen migration testi için uygun aday bulunamadı.', 1;

UPDATE dbo.PlayAwardCategories
SET IsActive = 0
WHERE Id = @CandidateId;

UPDATE dbo.Plays
SET IsActive = 0
WHERE Id = @PlayId;

/* This is the corrected activation statement from the migration that failed in
   the company environment. It must leave the inactive source untouched. */
UPDATE candidate
SET IsActive = 1,
    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
FROM dbo.PlayAwardCategories AS candidate
INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
WHERE candidate.AwardCategoryCode = 1002
  AND candidate.IsPublished = 1
  AND candidate.IsActive = 0
  AND play.IsPublished = 1
  AND play.IsActive = 1
  AND
  (
      play.SourceFormId IS NULL
      OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
  );

IF EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE Id = @CandidateId AND IsActive = 1
)
    THROW 52994, N'Pasif Form yönetmen adayı yanlışlıkla aktive edildi.', 1;

ROLLBACK TRANSACTION;
