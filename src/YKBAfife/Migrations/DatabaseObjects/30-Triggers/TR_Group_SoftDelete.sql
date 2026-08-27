CREATE OR ALTER TRIGGER dbo.TR_Group_SoftDelete ON dbo.[Group] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Group] target INNER JOIN deleted source ON source.Id = target.Id; END;
