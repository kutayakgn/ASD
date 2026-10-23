CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;

    /* The UPDATE trigger reassigns only these seasons' old/new ranges. */
END;
