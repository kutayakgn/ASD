CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingJuries_SoftDelete ON dbo.AdditionalVotingJuries INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.Id; END;
