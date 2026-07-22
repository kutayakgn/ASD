USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.Plays', N'RecordType') IS NULL
    BEGIN
        ALTER TABLE [dbo].[Plays]
            ADD [RecordType] bit NOT NULL
                CONSTRAINT [DF_Plays_RecordType] DEFAULT (0) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.Plays', N'FromKunye') IS NOT NULL
    BEGIN
        -- FromKunye = 1, RecordType = 0 (Kunye giris); FromKunye = 0, RecordType = 1 (Admin giris).
        EXEC sys.sp_executesql N'
            UPDATE [dbo].[Plays]
            SET [RecordType] = CASE WHEN [FromKunye] = 1 THEN 0 ELSE 1 END;';

        DECLARE @DefaultConstraintName sysname;

        SELECT @DefaultConstraintName = defaultConstraint.[name]
        FROM sys.default_constraints AS defaultConstraint
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.[object_id] = defaultConstraint.[parent_object_id]
           AND columnInfo.[column_id] = defaultConstraint.[parent_column_id]
        WHERE defaultConstraint.[parent_object_id] = OBJECT_ID(N'dbo.Plays')
          AND columnInfo.[name] = N'FromKunye';

        IF @DefaultConstraintName IS NOT NULL
        BEGIN
            DECLARE @DropConstraintSql nvarchar(max) =
                N'ALTER TABLE [dbo].[Plays] DROP CONSTRAINT ' + QUOTENAME(@DefaultConstraintName) + N';';
            EXEC sys.sp_executesql @DropConstraintSql;
        END;

        EXEC sys.sp_executesql N'ALTER TABLE [dbo].[Plays] DROP COLUMN [FromKunye];';
    END;

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
    columnInfo.[is_nullable] AS [IsNullable]
FROM sys.columns AS columnInfo
WHERE columnInfo.[object_id] = OBJECT_ID(N'dbo.Plays')
  AND columnInfo.[name] IN (N'FromKunye', N'RecordType');
GO