CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_ProtectDefaultCategory
ON dbo.PlayAwardCategories
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND candidate.RoleCode = 0
          AND play.RecordType = 0
    )
    BEGIN
        THROW 51307, N'Kunye oyunlarinin varsayilan 1001 kategori kaydi silinemez.', 1;
    END;
END;
