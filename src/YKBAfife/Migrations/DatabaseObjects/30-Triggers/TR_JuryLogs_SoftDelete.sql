CREATE OR ALTER TRIGGER dbo.TR_JuryLogs_SoftDelete
ON dbo.JuryLogs
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.JuryLogs AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;
END;
