CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDeleteDependents
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE vote SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes vote
    INNER JOIN inserted jury ON jury.Id = vote.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND vote.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted jury ON jury.Id = assignment.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted jury ON jury.Id = fee.UserId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted jury ON jury.Id = blacklist.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
