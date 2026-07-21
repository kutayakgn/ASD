USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
        THROW 51030, 'dbo.Users table was not found.', 1;

    IF COL_LENGTH(N'dbo.Users', N'IsActive') IS NULL
    BEGIN
        EXEC sys.sp_executesql
            N'ALTER TABLE [dbo].[Users] ADD [IsActive] bit NOT NULL DEFAULT (1) WITH VALUES;';

        EXEC sys.sp_executesql
            N';WITH JuryRows AS
              (
                  SELECT [Id], ROW_NUMBER() OVER (ORDER BY [Id]) AS [RowNumber]
                  FROM [dbo].[Users]
                  WHERE [RoleCode] = 2
              )
              UPDATE userInfo
              SET [IsActive] = CASE
                  WHEN jury.[RowNumber] % 3 = 0 THEN 0
                  ELSE 1
              END
              FROM [dbo].[Users] AS userInfo
              INNER JOIN JuryRows AS jury ON jury.[Id] = userInfo.[Id];';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS defaultConstraint
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.[object_id] = defaultConstraint.[parent_object_id]
           AND columnInfo.[column_id] = defaultConstraint.[parent_column_id]
        WHERE defaultConstraint.[parent_object_id] = OBJECT_ID(N'dbo.Users')
          AND columnInfo.[name] = N'IsActive'
    )
        EXEC sys.sp_executesql
            N'ALTER TABLE [dbo].[Users] ADD DEFAULT (1) FOR [IsActive];';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT [IsActive], COUNT(*) AS [JuryCount]
FROM [dbo].[Users]
WHERE [RoleCode] = 2
GROUP BY [IsActive]
ORDER BY [IsActive] DESC;
GO
