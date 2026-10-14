CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SoftDelete
ON dbo.PlayAwardCategories
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE AwardCategoryCode IN (1001, 1002))
        THROW 51307, N'System-managed categories 1001 and 1002 cannot be deleted.', 1;

    UPDATE target
    SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories target
    INNER JOIN deleted source ON source.Id = target.Id;
END;
