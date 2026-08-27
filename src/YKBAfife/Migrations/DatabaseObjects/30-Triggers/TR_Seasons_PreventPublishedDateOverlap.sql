CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
