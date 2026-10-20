CREATE OR ALTER TRIGGER dbo.TR_Configs_ProtectJuryHomePageSettings
ON dbo.Configs
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Only ConfigValue/audit fields are editable for the four fixed keys.
       Ordinary Config rows retain their existing edit/soft-delete behavior. */
    IF EXISTS
    (
        SELECT 1
        FROM deleted AS previous
        LEFT JOIN inserted AS currentRow ON currentRow.id = previous.id
        WHERE previous.ConfigName IN
            (N'HomePageJuryTableEnabled', N'HomePageMissionTableEnabled',
             N'HomePageMostWatchedTableEnabled', N'HomePageLeastWatchedTableEnabled')
          AND (currentRow.id IS NULL OR
               DATALENGTH(currentRow.ConfigName) <> DATALENGTH(previous.ConfigName) OR
               currentRow.ConfigName COLLATE Latin1_General_100_BIN2 <>
               previous.ConfigName COLLATE Latin1_General_100_BIN2)
    )
        THROW 53213, N'Jüri ana ekran tablo ayarlarının sabit adı veya kimliği değiştirilemez.', 1;
END;
