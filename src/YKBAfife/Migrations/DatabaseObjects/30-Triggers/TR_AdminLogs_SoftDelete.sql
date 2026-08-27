CREATE OR ALTER TRIGGER dbo.TR_AdminLogs_SoftDelete
ON dbo.AdminLogs
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.AdminLogs AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;
END;
