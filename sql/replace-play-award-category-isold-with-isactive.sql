USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
        THROW 51020, 'dbo.PlayAwardCategories table was not found.', 1;

    DECLARE @HasIsActive bit = CASE
        WHEN COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') IS NULL THEN 0
        ELSE 1
    END;
    DECLARE @HasIsOld bit = CASE
        WHEN COL_LENGTH(N'dbo.PlayAwardCategories', N'IsOld') IS NULL THEN 0
        ELSE 1
    END;

    IF @HasIsActive = 0
    BEGIN
        EXEC sys.sp_executesql
            N'ALTER TABLE [dbo].[PlayAwardCategories] ADD [IsActive] bit NULL;';

        IF @HasIsOld = 1
            EXEC sys.sp_executesql
                N'UPDATE [dbo].[PlayAwardCategories]
                  SET [IsActive] = CASE WHEN [IsOld] = 1 THEN 0 ELSE 1 END;';
        ELSE
            EXEC sys.sp_executesql
                N'UPDATE [dbo].[PlayAwardCategories] SET [IsActive] = 1;';
    END;

    EXEC sys.sp_executesql
        N'UPDATE [dbo].[PlayAwardCategories]
          SET [IsActive] = 1
          WHERE [IsActive] IS NULL;

          ALTER TABLE [dbo].[PlayAwardCategories]
              ALTER COLUMN [IsActive] bit NOT NULL;';

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS defaultConstraint
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.[object_id] = defaultConstraint.[parent_object_id]
           AND columnInfo.[column_id] = defaultConstraint.[parent_column_id]
        WHERE defaultConstraint.[parent_object_id] = OBJECT_ID(N'dbo.PlayAwardCategories')
          AND columnInfo.[name] = N'IsActive'
    )
        EXEC sys.sp_executesql
            N'ALTER TABLE [dbo].[PlayAwardCategories]
              ADD DEFAULT (1) FOR [IsActive];';

    IF @HasIsOld = 1
    BEGIN
        DECLARE @IsOldDefaultConstraint sysname;
        DECLARE @DropConstraintSql nvarchar(max);

        SELECT @IsOldDefaultConstraint = defaultConstraint.[name]
        FROM sys.default_constraints AS defaultConstraint
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.[object_id] = defaultConstraint.[parent_object_id]
           AND columnInfo.[column_id] = defaultConstraint.[parent_column_id]
        WHERE defaultConstraint.[parent_object_id] = OBJECT_ID(N'dbo.PlayAwardCategories')
          AND columnInfo.[name] = N'IsOld';

        IF @IsOldDefaultConstraint IS NOT NULL
        BEGIN
            SET @DropConstraintSql =
                N'ALTER TABLE [dbo].[PlayAwardCategories] DROP CONSTRAINT '
                + QUOTENAME(@IsOldDefaultConstraint) + N';';

            EXEC sys.sp_executesql @DropConstraintSql;
        END;

        EXEC sys.sp_executesql
            N'ALTER TABLE [dbo].[PlayAwardCategories] DROP COLUMN [IsOld];';
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
WHERE columnInfo.[object_id] = OBJECT_ID(N'dbo.PlayAwardCategories')
  AND columnInfo.[name] IN (N'IsActive', N'IsOld')
ORDER BY columnInfo.[column_id];
GO