SET XACT_ABORT ON;

/*
   CREATE OR ALTER still validates referenced columns while compiling modules.
   Keep every additive column required by Programmability.sql here so historical
   migrations that execute the current resource can safely upgrade legacy tables.
*/
IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;';
END;

IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
    THROW 52421, N'Programmability ön koşulu başarısız: dbo.Form.YoungGenerationArtist oluşturulamadı.', 1;
