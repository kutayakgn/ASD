CREATE OR ALTER TRIGGER dbo.TR_Manager_SoftDelete ON dbo.[Manager] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Manager] target INNER JOIN deleted source ON source.Id = target.Id; END;
