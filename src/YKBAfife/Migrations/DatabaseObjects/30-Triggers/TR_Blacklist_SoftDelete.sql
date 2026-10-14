CREATE OR ALTER TRIGGER dbo.TR_Blacklist_SoftDelete ON dbo.Blacklist INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Blacklist target INNER JOIN deleted source ON source.Id = target.Id; END;
