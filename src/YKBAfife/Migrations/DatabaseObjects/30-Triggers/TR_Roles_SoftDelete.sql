CREATE OR ALTER TRIGGER dbo.TR_Roles_SoftDelete ON dbo.Roles INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Roles target INNER JOIN deleted source ON source.Id = target.Id; END;
