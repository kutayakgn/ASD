CREATE OR ALTER TRIGGER [dbo].[TR_Plays_RecordTypeImmutable]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE currentPlay.[RecordType] <> previousPlay.[RecordType]
    )
    BEGIN
        THROW 51231, N'Mevcut bir oyunun RecordType degeri degistirilemez.', 1;
    END;
END;
