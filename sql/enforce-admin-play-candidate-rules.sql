USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Blacklist', N'U') IS NULL
BEGIN
    THROW 51210, N'Plays, PlayAwardCategories, JuryVotes veya Blacklist tablosu bulunamadı.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Invalid dependent rows are retained as soft-deleted history.
    UPDATE vote
    SET vote.[IsPublished] = 0,
        vote.[IsActive] = 0,
        vote.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[JuryVotes] AS vote
    INNER JOIN [dbo].[PlayAwardCategories] AS candidate
        ON candidate.[Id] = vote.[PlayAwardCategoryId]
    INNER JOIN [dbo].[Plays] AS play
        ON play.[Id] = candidate.[PlayId]
    WHERE play.[RecordType] = 1
      AND (vote.[IsPublished] = 1 OR vote.[IsActive] = 1);

    UPDATE candidate
    SET candidate.[IsPublished] = 0,
        candidate.[IsActive] = 0,
        candidate.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[PlayAwardCategories] AS candidate
    INNER JOIN [dbo].[Plays] AS play
        ON play.[Id] = candidate.[PlayId]
    WHERE play.[RecordType] = 1
      AND (candidate.[IsPublished] = 1 OR candidate.[IsActive] = 1);

    UPDATE blacklist
    SET blacklist.[IsPublished] = 0,
        blacklist.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[Blacklist] AS blacklist
    INNER JOIN [dbo].[Plays] AS play
        ON play.[Id] = blacklist.[PlayId]
    WHERE play.[RecordType] = 1
      AND blacklist.[IsPublished] = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_PlayAwardCategories_BlockAdminPlay]
ON [dbo].[PlayAwardCategories]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = candidate.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51211, N'RecordType 1 olan oyunlara aday veya ödül kategorisi eklenemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_BlockAdminRecordTypeWithCandidates]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE previousPlay.[RecordType] = 0
          AND currentPlay.[RecordType] = 1
    )
       AND
       (
           EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[PlayAwardCategories] AS candidate
                   ON candidate.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
           OR EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[Blacklist] AS blacklist
                   ON blacklist.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
       )
    BEGIN
        THROW 51212, N'Aday veya blacklist kaydı bulunan bir oyun RecordType 1 olarak değiştirilemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_BlockAdminPlay]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS blacklist
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = blacklist.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51213, N'RecordType 1 olan oyunlara blacklist kaydı eklenemez.', 1;
    END;
END;
GO

SELECT
    N'PlayAwardCategories' AS [SourceTable],
    candidate.[Id],
    candidate.[PlayId]
FROM [dbo].[PlayAwardCategories] AS candidate
INNER JOIN [dbo].[Plays] AS play
    ON play.[Id] = candidate.[PlayId]
WHERE play.[RecordType] = 1

UNION ALL

SELECT
    N'Blacklist' AS [SourceTable],
    blacklist.[Id],
    blacklist.[PlayId]
FROM [dbo].[Blacklist] AS blacklist
INNER JOIN [dbo].[Plays] AS play
    ON play.[Id] = blacklist.[PlayId]
WHERE play.[RecordType] = 1;
GO
