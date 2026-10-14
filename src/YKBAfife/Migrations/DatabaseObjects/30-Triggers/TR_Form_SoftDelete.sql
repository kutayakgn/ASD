CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    EXEC dbo.usp_SynchronizeFormsToPlays;
END;
