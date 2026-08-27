CREATE OR ALTER TRIGGER dbo.TR_UsersLog_SoftDelete ON dbo.UsersLog INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.UsersLog target INNER JOIN deleted source ON source.Id = target.Id; END;
