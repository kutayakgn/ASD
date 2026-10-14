/* EF soft deletes are UPDATE operations, so dependent rows are soft-deleted here. */
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDeleteDependents
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE candidate
    SET candidate.IsPublished = 0,
        candidate.IsActive = 0,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories candidate
    INNER JOIN inserted play ON play.Id = candidate.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND candidate.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted play ON play.Id = assignment.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted play ON play.Id = fee.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted play ON play.Id = blacklist.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
