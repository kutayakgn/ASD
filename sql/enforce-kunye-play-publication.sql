USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR COL_LENGTH(N'dbo.Plays', N'RecordType') IS NULL
   OR COL_LENGTH(N'dbo.Plays', N'IsPublished') IS NULL
BEGIN
    THROW 51500, N'Plays tablosu veya RecordType/IsPublished kolonlari bulunamadi.', 1;
END;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.Plays
    WHERE RecordType = 0
      AND IsPublished = 0
)
BEGIN
    SELECT Id, PlayName, TheaterName, RecordType, IsPublished
    FROM dbo.Plays
    WHERE RecordType = 0
      AND IsPublished = 0
    ORDER BY PlayName, Id;

    THROW 51501, N'IsPublished = 0 olan Kunye Giris oyunlari bulundu. Constraint eklenmeden once bu kayitlari ve iliskilerini kontrollu olarak restore edin.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.CK_Plays_KunyeMustRemainPublished', N'C') IS NULL
    BEGIN
        ALTER TABLE dbo.Plays WITH CHECK
            ADD CONSTRAINT CK_Plays_KunyeMustRemainPublished
                CHECK (RecordType = 1 OR IsPublished = 1);
    END;

    ALTER TABLE dbo.Plays WITH CHECK
        CHECK CONSTRAINT CK_Plays_KunyeMustRemainPublished;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
    BEGIN
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;
    END;

    UPDATE target
    SET target.IsPublished = 0
    FROM dbo.Plays AS target
    INNER JOIN deleted AS source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
GO

SELECT
    constraintInfo.name AS ConstraintName,
    constraintInfo.is_disabled AS IsDisabled,
    constraintInfo.is_not_trusted AS IsNotTrusted
FROM sys.check_constraints AS constraintInfo
WHERE constraintInfo.parent_object_id = OBJECT_ID(N'dbo.Plays')
  AND constraintInfo.name = N'CK_Plays_KunyeMustRemainPublished';
GO
