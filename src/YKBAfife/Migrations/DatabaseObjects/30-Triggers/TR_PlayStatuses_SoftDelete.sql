CREATE OR ALTER TRIGGER dbo.TR_PlayStatuses_SoftDelete ON dbo.PlayStatuses INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.PlayStatuses target INNER JOIN deleted source ON source.Id = target.Id; END;
