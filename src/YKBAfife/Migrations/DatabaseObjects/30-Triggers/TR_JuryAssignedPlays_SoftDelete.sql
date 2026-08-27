CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_SoftDelete ON dbo.JuryAssignedPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryAssignedPlays target INNER JOIN deleted source ON source.Id = target.Id; END;
