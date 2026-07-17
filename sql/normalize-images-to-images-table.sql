USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'[dbo].[Images]', N'U') IS NULL
    THROW 51000, 'Images table does not exist. Run add-afifeadmin-tables.sql first.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Never discard a path, URL or Base64 value silently. If this guard fails,
    -- import the actual image bytes into Images first and set the new FK column.
    IF COL_LENGTH(N'dbo.Announcements', N'Image') IS NOT NULL
        EXEC sys.sp_executesql N'
            IF EXISTS
            (
                SELECT 1 FROM [dbo].[Announcements]
                WHERE NULLIF(LTRIM(RTRIM([Image])), N'''') IS NOT NULL
            )
                THROW 51001, ''Announcements.Image contains legacy data. Import it into Images before migration.'', 1;';

    IF COL_LENGTH(N'dbo.Announcements', N'BackgroundImage') IS NOT NULL
        EXEC sys.sp_executesql N'
            IF EXISTS
            (
                SELECT 1 FROM [dbo].[Announcements]
                WHERE NULLIF(LTRIM(RTRIM([BackgroundImage])), N'''') IS NOT NULL
            )
                THROW 51002, ''Announcements.BackgroundImage contains legacy data. Import it into Images before migration.'', 1;';

    IF COL_LENGTH(N'dbo.Users', N'Photo') IS NOT NULL
        EXEC sys.sp_executesql N'
            IF EXISTS
            (
                SELECT 1 FROM [dbo].[Users]
                WHERE NULLIF(LTRIM(RTRIM([Photo])), N'''') IS NOT NULL
            )
                THROW 51003, ''Users.Photo contains legacy data. Import it into Images before migration.'', 1;';

    IF COL_LENGTH(N'dbo.PlayAwardCategories', N'Photo') IS NOT NULL
        EXEC sys.sp_executesql N'
            IF EXISTS
            (
                SELECT 1 FROM [dbo].[PlayAwardCategories]
                WHERE NULLIF(LTRIM(RTRIM([Photo])), N'''') IS NOT NULL
            )
                THROW 51004, ''PlayAwardCategories.Photo contains legacy data. Import it into Images before migration.'', 1;';

    IF COL_LENGTH(N'dbo.Announcements', N'ImageId') IS NULL
        ALTER TABLE [dbo].[Announcements] ADD [ImageId] uniqueidentifier NULL;

    IF COL_LENGTH(N'dbo.Announcements', N'BackgroundImageId') IS NULL
        ALTER TABLE [dbo].[Announcements] ADD [BackgroundImageId] uniqueidentifier NULL;

    IF COL_LENGTH(N'dbo.Users', N'PhotoImageId') IS NULL
        ALTER TABLE [dbo].[Users] ADD [PhotoImageId] uniqueidentifier NULL;

    IF COL_LENGTH(N'dbo.PlayAwardCategories', N'PhotoImageId') IS NULL
        ALTER TABLE [dbo].[PlayAwardCategories] ADD [PhotoImageId] uniqueidentifier NULL;

    -- Image GUIDs are immutable identifiers. SQL Server rejects two cascade paths
    -- from Images to Announcements, so image keys use NO ACTION for update/delete.
    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_ImageId]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Announcements] DROP CONSTRAINT [FK_Announcements_Images_ImageId];

    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_BackgroundImageId]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Announcements] DROP CONSTRAINT [FK_Announcements_Images_BackgroundImageId];

    IF OBJECT_ID(N'[dbo].[FK_Users_Images_PhotoImageId]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Users] DROP CONSTRAINT [FK_Users_Images_PhotoImageId];

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_Images_PhotoImageId]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[PlayAwardCategories] DROP CONSTRAINT [FK_PlayAwardCategories_Images_PhotoImageId];
    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_ImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Announcements] WITH CHECK
            ADD CONSTRAINT [FK_Announcements_Images_ImageId]
            FOREIGN KEY ([ImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_BackgroundImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Announcements] WITH CHECK
            ADD CONSTRAINT [FK_Announcements_Images_BackgroundImageId]
            FOREIGN KEY ([BackgroundImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_Users_Images_PhotoImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Users] WITH CHECK
            ADD CONSTRAINT [FK_Users_Images_PhotoImageId]
            FOREIGN KEY ([PhotoImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_Images_PhotoImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
            ADD CONSTRAINT [FK_PlayAwardCategories_Images_PhotoImageId]
            FOREIGN KEY ([PhotoImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[Announcements]')
          AND [name] = N'IX_Announcements_ImageId'
    )
        CREATE INDEX [IX_Announcements_ImageId] ON [dbo].[Announcements] ([ImageId]);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[Announcements]')
          AND [name] = N'IX_Announcements_BackgroundImageId'
    )
        CREATE INDEX [IX_Announcements_BackgroundImageId] ON [dbo].[Announcements] ([BackgroundImageId]);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[Users]')
          AND [name] = N'IX_Users_PhotoImageId'
    )
        CREATE INDEX [IX_Users_PhotoImageId] ON [dbo].[Users] ([PhotoImageId]);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[PlayAwardCategories]')
          AND [name] = N'IX_PlayAwardCategories_PhotoImageId'
    )
        CREATE INDEX [IX_PlayAwardCategories_PhotoImageId]
            ON [dbo].[PlayAwardCategories] ([PhotoImageId]);

    -- The old columns are removed only after all guards and new relationships succeed.
    IF COL_LENGTH(N'dbo.Announcements', N'Image') IS NOT NULL
        EXEC(N'ALTER TABLE [dbo].[Announcements] DROP COLUMN [Image];');

    IF COL_LENGTH(N'dbo.Announcements', N'BackgroundImage') IS NOT NULL
        EXEC(N'ALTER TABLE [dbo].[Announcements] DROP COLUMN [BackgroundImage];');

    IF COL_LENGTH(N'dbo.Users', N'Photo') IS NOT NULL
        EXEC(N'ALTER TABLE [dbo].[Users] DROP COLUMN [Photo];');

    IF COL_LENGTH(N'dbo.PlayAwardCategories', N'Photo') IS NOT NULL
        EXEC(N'ALTER TABLE [dbo].[PlayAwardCategories] DROP COLUMN [Photo];');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    tableInfo.[TableName],
    tableInfo.[ColumnName],
    TYPE_NAME(columnInfo.[user_type_id]) AS [DataType],
    columnInfo.[is_nullable] AS [IsNullable]
FROM
(
    VALUES
        (N'Announcements', N'ImageId'),
        (N'Announcements', N'BackgroundImageId'),
        (N'Users', N'PhotoImageId'),
        (N'PlayAwardCategories', N'PhotoImageId')
) AS tableInfo([TableName], [ColumnName])
INNER JOIN sys.columns AS columnInfo
    ON columnInfo.[object_id] = OBJECT_ID(N'dbo.' + tableInfo.[TableName])
   AND columnInfo.[name] = tableInfo.[ColumnName]
ORDER BY tableInfo.[TableName], tableInfo.[ColumnName];

SELECT
    fk.[name] AS [ForeignKey],
    OBJECT_NAME(fk.[parent_object_id]) AS [SourceTable],
    fk.[update_referential_action_desc] AS [OnUpdate],
    fk.[delete_referential_action_desc] AS [OnDelete]
FROM sys.foreign_keys AS fk
WHERE fk.[name] IN
(
    N'FK_Announcements_Images_ImageId',
    N'FK_Announcements_Images_BackgroundImageId',
    N'FK_Users_Images_PhotoImageId',
    N'FK_PlayAwardCategories_Images_PhotoImageId'
)
ORDER BY fk.[name];
GO

