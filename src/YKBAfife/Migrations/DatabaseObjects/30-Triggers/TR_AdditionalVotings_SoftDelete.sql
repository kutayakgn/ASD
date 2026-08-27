CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotings_SoftDelete
ON dbo.AdditionalVotings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2(7) = SYSDATETIME();
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotings target INNER JOIN deleted d ON d.Id = target.Id;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
END;
