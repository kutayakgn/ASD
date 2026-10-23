/* Previous productions cannot acquire director or technical-category candidates.
   Historical rows remain available when all three eligibility flags are off.
   Do not bypass this rule during lifecycle restoration: that must not resurrect
   a category excluded by the current Form contract. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockPreviousProduction
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        WHERE formRecord.previousProductionVersion = 1
          AND (candidate.AwardCategoryCode = 1002
               OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011)
          AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1)
    )
        THROW 52434, N'Önceki prodüksiyon başvurularına yönetmen veya teknik kategori adayı eklenemez.', 1;
END;
