/* Reject new visible relationships while their source Form is inactive. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockInactiveSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52410, N'Pasif Form kaynağına yayımlanmış aday/kategori eklenemez.', 1;
END;
