CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* The Form synchronizer writes a complete snapshot inside one transaction.
       Permit it to normalize legacy intermediate values; normal application
       writes remain protected by every check below. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE AwardCategoryCode = 1012
          AND (IsPublished = 1 OR IsActive = 1 OR IsCurrent = 1)
    )
        THROW 52430, N'1012 ödül kategorisi sistemden kaldırılmıştır.', 1;

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
              play.RecordType <> 0
              OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
              OR candidate.Candidate <> play.TheaterName
              OR (candidate.RoleCode = 0 AND candidate.IsCurrent <> 1)
              OR
              (
                  candidate.RoleCode <> 0
                  AND
                  (
                      previousCandidate.Id IS NULL
                      OR previousCandidate.PlayId <> candidate.PlayId
                      OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                      OR previousCandidate.RoleCode <> candidate.RoleCode
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

        /* RoleCode is the stable identity. Role is editable display data and
           distinct role slots may intentionally use the same display name. */
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
