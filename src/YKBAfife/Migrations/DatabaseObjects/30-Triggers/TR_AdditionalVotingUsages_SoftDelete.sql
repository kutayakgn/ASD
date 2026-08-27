CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingUsages_SoftDelete ON dbo.AdditionalVotingUsages INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.Id; END;
