CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualDelete
ON dbo.Rankings
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52003,
        N'Rankings rows cannot be deleted manually.',
        1;
END;
