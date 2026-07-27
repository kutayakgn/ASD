USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.AwardCategories', N'U') IS NULL
BEGIN
    THROW 51400, N'AwardCategories tablosu bulunamadi.', 1;
END;
GO

IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NULL
BEGIN
    THROW 51401, N'Once MultiCandidate migration scriptini calistirin.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ColumnAdded bit = 0;

    IF COL_LENGTH(N'dbo.AwardCategories', N'HasRoleAndPhoto') IS NULL
    BEGIN
        ALTER TABLE dbo.AwardCategories
            ADD HasRoleAndPhoto bit NOT NULL
                CONSTRAINT DF_AwardCategories_HasRoleAndPhoto DEFAULT (0) WITH VALUES;
        SET @ColumnAdded = 1;
    END;

    -- CategoryCode and the canonical category rows are immutable. Initial
    -- metadata mirrors MultiCandidate, but reruns preserve later deliberate edits.
    IF @ColumnAdded = 1
    BEGIN
        EXEC sys.sp_executesql N'
            UPDATE dbo.AwardCategories
            SET HasRoleAndPhoto = MultiCandidate;';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

EXEC sys.sp_executesql N'
    SELECT CategoryCode, CategoryName, MultiCandidate, HasRoleAndPhoto
    FROM dbo.AwardCategories
    ORDER BY CategoryCode;';
GO
