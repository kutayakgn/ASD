CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_BlockInactiveSourceForm
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changed.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52411, N'Pasif Form kaynağı için yayımlanmış jüri oyu eklenemez.', 1;
END;
