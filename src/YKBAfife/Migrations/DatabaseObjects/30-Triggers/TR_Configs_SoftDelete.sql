CREATE OR ALTER TRIGGER dbo.TR_Configs_SoftDelete ON dbo.Configs INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Configs target INNER JOIN deleted source ON source.Id = target.Id; END;
