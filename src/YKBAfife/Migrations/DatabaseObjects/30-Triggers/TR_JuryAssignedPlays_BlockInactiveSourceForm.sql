CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_BlockInactiveSourceForm
ON dbo.JuryAssignedPlays
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
        THROW 52413, N'Pasif Form kaynağı için yayımlanmış jüri ataması eklenemez.', 1;
END;
