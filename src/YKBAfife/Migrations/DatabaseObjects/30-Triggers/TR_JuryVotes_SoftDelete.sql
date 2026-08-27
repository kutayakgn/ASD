CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SoftDelete ON dbo.JuryVotes INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.JuryVotes target INNER JOIN deleted source ON source.Id = target.Id; END;
