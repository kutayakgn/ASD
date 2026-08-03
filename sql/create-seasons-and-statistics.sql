SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Seasons', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Seasons
        (
            Id uniqueidentifier NOT NULL
                CONSTRAINT DF_Seasons_Id DEFAULT (NEWSEQUENTIALID()),
            SeasonStartDate date NOT NULL,
            SeasonEndDate date NOT NULL,
            KunyeRegistrationStartDate date NOT NULL,
            KunyeRegistrationEndDate date NOT NULL,
            VotingStartDate date NOT NULL,
            VotingEndDate date NOT NULL,
            PlayCount int NOT NULL CONSTRAINT DF_Seasons_PlayCount DEFAULT (0),
            ActivePlayCount int NOT NULL CONSTRAINT DF_Seasons_ActivePlayCount DEFAULT (0),
            VoteCount int NOT NULL CONSTRAINT DF_Seasons_VoteCount DEFAULT (0),
            IsPublished bit NOT NULL CONSTRAINT DF_Seasons_IsPublished DEFAULT (1),
            CONSTRAINT PK_Seasons PRIMARY KEY CLUSTERED (Id),
            CONSTRAINT CK_Seasons_SeasonDateRange
                CHECK (SeasonStartDate < SeasonEndDate),
            CONSTRAINT CK_Seasons_KunyeRegistrationDateRange
                CHECK (
                    KunyeRegistrationStartDate < KunyeRegistrationEndDate
                    AND KunyeRegistrationStartDate >= SeasonStartDate
                    AND KunyeRegistrationEndDate <= SeasonEndDate),
            CONSTRAINT CK_Seasons_VotingDateRange
                CHECK (
                    VotingStartDate < VotingEndDate
                    AND VotingStartDate >= SeasonStartDate
                    AND VotingEndDate <= SeasonEndDate),
            CONSTRAINT CK_Seasons_NonNegativeCounts
                CHECK (PlayCount >= 0 AND ActivePlayCount >= 0 AND VoteCount >= 0)
        );
    END;

    IF COL_LENGTH(N'dbo.Seasons', N'Id') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'SeasonStartDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'SeasonEndDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'KunyeRegistrationStartDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'KunyeRegistrationEndDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'VotingStartDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'VotingEndDate') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'PlayCount') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'ActivePlayCount') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'VoteCount') IS NULL
       OR COL_LENGTH(N'dbo.Seasons', N'IsPublished') IS NULL
    BEGIN
        THROW 51900, N'dbo.Seasons exists but does not have the expected schema.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Seasons')
          AND name = N'UX_Seasons_PublishedDateRange'
    )
    BEGIN
        CREATE UNIQUE INDEX UX_Seasons_PublishedDateRange
            ON dbo.Seasons (SeasonStartDate, SeasonEndDate)
            WHERE IsPublished = 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Plays')
          AND name = N'IX_Plays_SeasonStatistics'
    )
    BEGIN
        CREATE INDEX IX_Plays_SeasonStatistics
            ON dbo.Plays (CreatedAt)
            INCLUDE (IsPublished, StatusCode)
            WHERE CreatedAt IS NOT NULL;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.JuryVotes')
          AND name = N'IX_JuryVotes_SeasonStatistics'
    )
    BEGIN
        CREATE INDEX IX_JuryVotes_SeasonStatistics
            ON dbo.JuryVotes (CreatedAt)
            INCLUDE (IsPublished, IsActive)
            WHERE CreatedAt IS NOT NULL;
    END;

    DECLARE @CurrentLocalDate date = CONVERT(date, DATEADD(HOUR, 3, SYSUTCDATETIME()));
    DECLARE @LatestSeasonStartYear int =
        CASE
            WHEN MONTH(@CurrentLocalDate) >= 9 THEN YEAR(@CurrentLocalDate)
            ELSE YEAR(@CurrentLocalDate) - 1
        END;
    DECLARE @SeasonStartYear int = 2018;

    WHILE @SeasonStartYear <= @LatestSeasonStartYear
    BEGIN
        DECLARE @SeasonStartDate date = DATEFROMPARTS(@SeasonStartYear, 9, 1);
        DECLARE @SeasonEndDate date = DATEFROMPARTS(@SeasonStartYear + 1, 5, 1);

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Seasons
            WHERE SeasonStartDate = @SeasonStartDate
              AND SeasonEndDate = @SeasonEndDate
              AND IsPublished = 1
        )
        BEGIN
            INSERT INTO dbo.Seasons
            (
                Id,
                SeasonStartDate,
                SeasonEndDate,
                KunyeRegistrationStartDate,
                KunyeRegistrationEndDate,
                VotingStartDate,
                VotingEndDate,
                PlayCount,
                ActivePlayCount,
                VoteCount,
                IsPublished
            )
            VALUES
            (
                NEWID(),
                @SeasonStartDate,
                @SeasonEndDate,
                DATEFROMPARTS(@SeasonStartYear, 9, 1),
                DATEFROMPARTS(@SeasonStartYear, 12, 31),
                DATEFROMPARTS(@SeasonStartYear + 1, 1, 1),
                DATEFROMPARTS(@SeasonStartYear + 1, 4, 30),
                0,
                0,
                0,
                1
            );
        END;

        SET @SeasonStartYear += 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshSeasonStatistics
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;

    UPDATE season
    SET
        PlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        ActivePlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.StatusCode = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        VoteCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.JuryVotes AS vote
            INNER JOIN dbo.PlayAwardCategories AS candidate
                ON candidate.Id = vote.PlayAwardCategoryId
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
              AND candidate.IsPublished = 1
              AND candidate.IsActive = 1
              AND play.IsPublished = 1
              AND play.IsActive = 1
              AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        )
    FROM dbo.Seasons AS season
    WHERE season.IsPublished = 1
      AND
      (
          @FromDate IS NULL
          OR
          (
              @FromDate < CONVERT(datetime2(7), season.SeasonEndDate)
              AND @ToDate >= CONVERT(datetime2(7), season.SeasonStartDate)
          )
      );
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(CreatedAt) OR UPDATE(IsPublished) OR UPDATE(IsActive) OR UPDATE(StatusCode))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.CreatedAt),
        @ToDate = MAX(changed.CreatedAt)
    FROM
    (
        SELECT CreatedAt FROM inserted WHERE CreatedAt IS NOT NULL
        UNION ALL
        SELECT CreatedAt FROM deleted WHERE CreatedAt IS NOT NULL
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshSeasonStatistics
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(CreatedAt) OR UPDATE(IsPublished) OR UPDATE(IsActive))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.CreatedAt),
        @ToDate = MAX(changed.CreatedAt)
    FROM
    (
        SELECT CreatedAt FROM inserted WHERE CreatedAt IS NOT NULL
        UNION ALL
        SELECT CreatedAt FROM deleted WHERE CreatedAt IS NOT NULL
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.RangeDate),
        @ToDate = MAX(changed.RangeDate)
    FROM
    (
        SELECT CONVERT(datetime2(7), SeasonStartDate) AS RangeDate FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonStartDate) FROM deleted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM deleted
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;
END;
GO

EXEC dbo.usp_RefreshSeasonStatistics;
GO

SELECT
    Id,
    SeasonStartDate,
    SeasonEndDate,
    KunyeRegistrationStartDate,
    KunyeRegistrationEndDate,
    VotingStartDate,
    VotingEndDate,
    PlayCount,
    ActivePlayCount,
    VoteCount,
    IsPublished
FROM dbo.Seasons
WHERE IsPublished = 1
ORDER BY SeasonStartDate DESC;
GO