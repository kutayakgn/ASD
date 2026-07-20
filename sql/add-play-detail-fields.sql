USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.Plays', N'JuriOylamaStatus') IS NULL
        ALTER TABLE [dbo].[Plays]
            ADD [JuriOylamaStatus] nvarchar(50) NULL;

    IF COL_LENGTH(N'dbo.Plays', N'KunyeGirisStatus') IS NULL
        ALTER TABLE [dbo].[Plays]
            ADD [KunyeGirisStatus] nvarchar(50) NULL;

    IF COL_LENGTH(N'dbo.Plays', lays tablosunda Record') IS NULL
        ALTER TABLE [dbo].[Plays]
            ADD [RecordType] nvarchar(50) NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    columnInfo.[name] AS [ColumnName],
    TYPE_NAME(columnInfo.[user_type_id]) AS [DataType],
    columnInfo.[max_length] AS [MaxLength],
    columnInfo.[is_nullable] AS [IsNullable]
FROM sys.columns AS columnInfo
WHERE columnInfo.[object_id] = OBJECT_ID(N'dbo.Plays')
  AND columnInfo.[name] IN (N'JuriOylamaStatus', N'KunyeGirisStatus', N'RecordType')
ORDER BY columnInfo.[column_id];
GO
