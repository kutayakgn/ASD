CREATE OR ALTER TRIGGER dbo.TR_Images_SoftDelete ON dbo.Images INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Images target INNER JOIN deleted source ON source.Id = target.Id; END;
