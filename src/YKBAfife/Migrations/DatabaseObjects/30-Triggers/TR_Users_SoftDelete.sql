CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDelete ON dbo.Users INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.Users target INNER JOIN deleted source ON source.Id = target.Id; END;
