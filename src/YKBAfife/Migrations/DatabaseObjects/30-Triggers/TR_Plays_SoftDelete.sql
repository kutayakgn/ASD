CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.Plays target
    INNER JOIN deleted source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
