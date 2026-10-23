CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    /* The UPDATE above already passes this statement's IDs through the Form
       INSERT/UPDATE trigger. Keep soft deletion within the same scope as well;
       never fall back to a full-history repair from a DELETE statement. */
    DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM deleted FOR JSON PATH);
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
END;
