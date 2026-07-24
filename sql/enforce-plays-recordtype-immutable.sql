USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR COL_LENGTH(N'dbo.Plays', N'RecordType') IS NULL
BEGIN
    THROW 51230, N'Plays tablosu veya RecordType kolonu bulunamadi.', 1;
END;
GO

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
GO

SELECT
    triggerInfo.[name] AS [TriggerName],
    triggerInfo.[is_disabled] AS [IsDisabled]
FROM sys.triggers AS triggerInfo
WHERE triggerInfo.[parent_id] = OBJECT_ID(N'dbo.Plays')
  AND triggerInfo.[name] = N'TR_Plays_RecordTypeImmutable';
GO