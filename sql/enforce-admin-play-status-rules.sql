USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.Plays', N'RecordType') IS NULL
       OR COL_LENGTH(N'dbo.Plays', N'JuriOylamaStatus') IS NULL
       OR COL_LENGTH(N'dbo.Plays', N'KunyeGirisStatus') IS NULL
       OR COL_LENGTH(N'dbo.Plays', N'StatusCode') IS NULL
    BEGIN
        THROW 50001, N'Plays tablosunda gerekli statü kolonlarından biri bulunamadı.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[PlayStatuses]
        WHERE [StatusCode] = 6
    )
    BEGIN
        THROW 50002, N'StatusCode 6 bulunamadığı için mevcut admin oyunları normalize edilemedi.', 1;
    END;

    UPDATE [dbo].[Plays]
    SET [JuriOylamaStatus] = 0,
        [KunyeGirisStatus] = 0
    WHERE [RecordType] = 1
      AND ([JuriOylamaStatus] <> 0 OR [KunyeGirisStatus] <> 0);

    -- StatusCode 6 canonical "Sistemde Aktif Değil" kaydıdır.
    UPDATE [dbo].[Plays]
    SET [StatusCode] = 6
    WHERE [RecordType] = 1
      AND [StatusCode] = 1;

    IF OBJECT_ID(N'dbo.CK_Plays_AdminRecord_StatusesDisabled', N'C') IS NOT NULL
    BEGIN
        ALTER TABLE [dbo].[Plays]
            DROP CONSTRAINT [CK_Plays_AdminRecord_StatusesDisabled];
    END;

    IF OBJECT_ID(N'dbo.CK_Plays_AdminRecord_StatusCode', N'C') IS NOT NULL
    BEGIN
        ALTER TABLE [dbo].[Plays]
            DROP CONSTRAINT [CK_Plays_AdminRecord_StatusCode];
    END;

    ALTER TABLE [dbo].[Plays] WITH CHECK
        ADD CONSTRAINT [CK_Plays_AdminRecord_StatusesDisabled]
        CHECK
        (
            [RecordType] = 0
            OR ([JuriOylamaStatus] = 0 AND [KunyeGirisStatus] = 0)
        );

    ALTER TABLE [dbo].[Plays] WITH CHECK
        ADD CONSTRAINT [CK_Plays_AdminRecord_StatusCode]
        CHECK ([RecordType] = 0 OR [StatusCode] <> 1);

    ALTER TABLE [dbo].[Plays]
        CHECK CONSTRAINT [CK_Plays_AdminRecord_StatusesDisabled];

    ALTER TABLE [dbo].[Plays]
        CHECK CONSTRAINT [CK_Plays_AdminRecord_StatusCode];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    [Id],
    [PlayName],
    [RecordType],
    [StatusCode],
    [JuriOylamaStatus],
    [KunyeGirisStatus]
FROM [dbo].[Plays]
WHERE [RecordType] = 1
  AND
  (
      [StatusCode] = 1
      OR [JuriOylamaStatus] <> 0
      OR [KunyeGirisStatus] <> 0
  );
GO
