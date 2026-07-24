USE [AfifeAdmin];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.AwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
BEGIN
    THROW 51300, N'AwardCategories, Plays veya PlayAwardCategories tablosu bulunamadi.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF (
        SELECT COUNT_BIG(*)
        FROM dbo.AwardCategories
        WHERE CategoryCode BETWEEN 1001 AND 1012
    ) <> 12
    BEGIN
        THROW 51301, N'Kanonik 1001-1012 odul kategorilerinin tamami bulunamadi.', 1;
    END;

    IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NULL
    BEGIN
        ALTER TABLE dbo.AwardCategories
            ADD MultiCandidate bit NOT NULL
                CONSTRAINT DF_AwardCategories_MultiCandidate DEFAULT (0) WITH VALUES;
    END;

    -- CategoryCode values and category identities are not changed. Only the new
    -- multiplicity metadata is assigned to the canonical rows.
    EXEC sys.sp_executesql N'
        UPDATE dbo.AwardCategories
        SET MultiCandidate = CASE
            WHEN CategoryCode IN (1003, 1004, 1005, 1006, 1012) THEN 1
            ELSE 0
        END
        WHERE CategoryCode BETWEEN 1001 AND 1012;';

    -- Preserve every legacy 1001 row, but select one canonical default slot for
    -- each Kunye play. Other rows remain historical and are not deleted.
    DECLARE @CanonicalDefaultRows TABLE
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        PlayId uniqueidentifier NOT NULL UNIQUE
    );

    ;WITH RankedDefaults AS
    (
        SELECT
            candidate.Id,
            candidate.PlayId,
            ROW_NUMBER() OVER
            (
                PARTITION BY candidate.PlayId
                ORDER BY
                    CASE WHEN candidate.RoleCode = 0 THEN 0 ELSE 1 END,
                    CASE WHEN candidate.RoleCode = 1001 THEN 0 ELSE 1 END,
                    CASE WHEN candidate.Role = N'Oyun' THEN 0 ELSE 1 END,
                    candidate.IsCurrent DESC,
                    candidate.IsPublished DESC,
                    COALESCE(candidate.UpdatedAt, candidate.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    candidate.Id
            ) AS CandidateOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND play.RecordType = 0
    )
    INSERT INTO @CanonicalDefaultRows (Id, PlayId)
    SELECT Id, PlayId
    FROM RankedDefaults
    WHERE CandidateOrder = 1;

    UPDATE candidate
    SET
        candidate.IsCurrent = 0,
        candidate.UpdatedAt = COALESCE(candidate.UpdatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME()))
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    WHERE candidate.AwardCategoryCode = 1001
      AND play.RecordType = 0
      AND candidate.IsCurrent = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM @CanonicalDefaultRows AS canonical
          WHERE canonical.Id = candidate.Id
      );

    UPDATE candidate
    SET
        candidate.Candidate = play.TheaterName,
        candidate.Role = NULL,
        candidate.RoleCode = 0,
        candidate.IsCurrent = 1,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        candidate.UpdatedBy = play.UpdatedBy
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN @CanonicalDefaultRows AS canonical ON canonical.Id = candidate.Id
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id,
        PlayId,
        CreatedAt,
        CreatedBy,
        UpdatedAt,
        UpdatedBy,
        IsPublished,
        Candidate,
        AwardCategoryCode,
        IsCurrent,
        Role,
        RoleCode,
        PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        play.IsPublished,
        play.TheaterName,
        1001,
        1,
        NULL,
        0,
        NULL
    FROM dbo.Plays AS play
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
          AND name = N'UX_PlayAwardCategories_DefaultPlayCategory'
    )
    BEGIN
        CREATE UNIQUE INDEX UX_PlayAwardCategories_DefaultPlayCategory
            ON dbo.PlayAwardCategories (PlayId)
            WHERE AwardCategoryCode = 1001 AND RoleCode = 0;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- The 1001 row is a system-managed category slot, not a person candidate.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE candidate.AwardCategoryCode = 1001
          AND
          (
              (
                  candidate.RoleCode = 0
                  AND
                  (
                      play.RecordType <> 0
                      OR candidate.Role IS NOT NULL
                      OR candidate.IsCurrent <> 1
                      OR candidate.Candidate <> play.TheaterName
                  )
              )
              OR
              (
                  candidate.RoleCode <> 0
                  AND
                  (
                      previousCandidate.Id IS NULL
                      OR previousCandidate.PlayId <> candidate.PlayId
                      OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                      OR previousCandidate.RoleCode <> candidate.RoleCode
                      OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                      OR previousCandidate.Candidate <> candidate.Candidate
                  )
              )
          )
    )
    BEGIN
        THROW 51302, N'1001 varsayilan oyun kategorisi sistem tarafindan yonetilir ve degistirilemez.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.Id IS NULL
           OR previousCandidate.PlayId <> candidate.PlayId
           OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
           OR previousCandidate.RoleCode <> candidate.RoleCode
           OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND (candidate.RoleCode <= 0 OR NULLIF(LTRIM(RTRIM(candidate.Role)), N'') IS NULL)
        )
        BEGIN
            THROW 51303, N'Cok adayli kategorilerde pozitif RoleCode ve dolu Role alani zorunludur.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            OUTER APPLY
            (
                SELECT TOP (1) existing.RoleCode
                FROM dbo.PlayAwardCategories AS existing
                WHERE existing.Id <> candidate.Id
                  AND existing.PlayId = candidate.PlayId
                  AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                ORDER BY
                    existing.IsCurrent DESC,
                    COALESCE(existing.UpdatedAt, existing.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    existing.Id
            ) AS canonicalSlot
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 0
                AND candidate.AwardCategoryCode <> 1001
                AND
                (
                    candidate.Role IS NOT NULL
                    OR candidate.RoleCode <> COALESCE(canonicalSlot.RoleCode, 0)
                )
        )
        BEGIN
            THROW 51304, N'Tek adayli kategoriler yalnizca tek mantiksal slot ve bos Role alani kullanabilir.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            INNER JOIN dbo.PlayAwardCategories AS existing
                ON existing.Id <> candidate.Id
               AND existing.PlayId = candidate.PlayId
               AND existing.AwardCategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND
                (
                    (existing.RoleCode = candidate.RoleCode AND LTRIM(RTRIM(existing.Role)) <> LTRIM(RTRIM(candidate.Role)))
                    OR
                    (existing.RoleCode <> candidate.RoleCode AND LTRIM(RTRIM(existing.Role)) = LTRIM(RTRIM(candidate.Role)))
                )
        )
        BEGIN
            THROW 51305, N'Bir rol adi tek RoleCode ile, bir RoleCode da tek rol adi ile eslesmelidir.', 1;
        END;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        INNER JOIN dbo.AwardCategories AS category
            ON category.CategoryCode = candidate.AwardCategoryCode
        WHERE category.MultiCandidate = 0
          AND (previousCandidate.Id IS NULL OR previousCandidate.IsCurrent <> candidate.IsCurrent)
          AND
          (
              SELECT COUNT_BIG(*)
              FROM dbo.PlayAwardCategories AS currentCandidate
              WHERE currentCandidate.PlayId = candidate.PlayId
                AND currentCandidate.AwardCategoryCode = candidate.AwardCategoryCode
                AND currentCandidate.IsCurrent = 1
          ) > 1
    )
    BEGIN
        THROW 51306, N'Tek adayli kategorilerde ayni anda yalnizca bir guncel aday olabilir.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_EnsureDefaultAwardCategory
ON dbo.Plays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE defaultCategory
    SET
        defaultCategory.Candidate = currentPlay.TheaterName,
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND defaultCategory.RoleCode = 0
      AND currentPlay.TheaterName <> previousPlay.TheaterName;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        play.IsPublished,
        play.TheaterName,
        1001,
        1,
        NULL,
        0,
        NULL
    FROM inserted AS play
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_ProtectDefaultCategory
ON dbo.PlayAwardCategories
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND candidate.RoleCode = 0
          AND play.RecordType = 0
    )
    BEGIN
        THROW 51307, N'Kunye oyunlarinin varsayilan 1001 kategori kaydi silinemez.', 1;
    END;
END;
GO

-- Audit only: these queries do not modify legacy rows. Review results manually.
SELECT
    category.CategoryCode,
    category.CategoryName,
    category.MultiCandidate
FROM dbo.AwardCategories AS category
WHERE category.CategoryCode BETWEEN 1001 AND 1012
ORDER BY category.CategoryCode;

SELECT
    candidate.PlayId,
    play.PlayName,
    candidate.AwardCategoryCode,
    COUNT_BIG(*) AS CurrentCandidateCount
FROM dbo.PlayAwardCategories AS candidate
INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
INNER JOIN dbo.AwardCategories AS category ON category.CategoryCode = candidate.AwardCategoryCode
WHERE category.MultiCandidate = 0
  AND candidate.IsCurrent = 1
GROUP BY candidate.PlayId, play.PlayName, candidate.AwardCategoryCode
HAVING COUNT_BIG(*) > 1;

SELECT
    play.Id,
    play.PlayName
FROM dbo.Plays AS play
WHERE play.RecordType = 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.PlayAwardCategories AS candidate
      WHERE candidate.PlayId = play.Id
        AND candidate.AwardCategoryCode = 1001
        AND candidate.RoleCode = 0
  );
GO