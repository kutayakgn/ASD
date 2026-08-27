CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingPlays_SoftDelete ON dbo.AdditionalVotingPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.Id; END;
