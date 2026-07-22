SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.AwardCategories', N'U') IS NULL OR
       OBJECT_ID(N'dbo.PlayStatuses', N'U') IS NULL OR
       OBJECT_ID(N'dbo.Plays', N'U') IS NULL OR
       OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL OR
       OBJECT_ID(N'dbo.Users', N'U') IS NULL OR
       OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
        THROW 51100, 'Required AfifeAdmin tables were not found.', 1;

    IF OBJECT_ID(N'dbo.TR_JuryVotes_SingleRecordPerPlayCategoryRole', N'TR') IS NULL OR
       OBJECT_ID(N'dbo.TR_PlayAwardCategories_SynchronizeJuryVotes', N'TR') IS NULL
        THROW 51105, 'Run migrate-candidate-publication-and-jury-vote-rules.sql before this seed script.', 1;

    DECLARE @AwardCategories TABLE
    (
        Id uniqueidentifier NOT NULL,
        CategoryCode int NOT NULL,
        CategoryName nvarchar(250) NOT NULL,
        RoleCode int NOT NULL,
        RoleName nvarchar(200) NULL,
        CurrentCandidate nvarchar(250) NOT NULL,
        OldCandidate nvarchar(250) NULL
    );

    INSERT INTO @AwardCategories
        (Id, CategoryCode, CategoryName, RoleCode, RoleName, CurrentCandidate, OldCandidate)
    VALUES
        ('40000000-0000-0000-0000-000000000001', 1001, N'Yılın En Başarılı Oyunu', 1001, N'Oyun', N'Afife Test Topluluğu', NULL),
        ('40000000-0000-0000-0000-000000000002', 1002, N'Yılın En Başarılı Yönetmeni', 1002, N'Yönetmen', N'Deniz Aksoy', NULL),
        ('40000000-0000-0000-0000-000000000003', 1003, N'Yılın En Başarılı Kadın Oyuncusu', 1003, N'Başrol', N'Selin Yalçın', N'Aylin Demir'),
        ('40000000-0000-0000-0000-000000000004', 1004, N'Yılın En Başarılı Erkek Oyuncusu', 1004, N'Başrol', N'Mert Karaca', N'Kerem Tunç'),
        ('40000000-0000-0000-0000-000000000005', 1005, N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', 1005, N'Yardımcı Rol', N'Ece Koral', NULL),
        ('40000000-0000-0000-0000-000000000006', 1006, N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', 1006, N'Yardımcı Rol', N'Barış Aydın', NULL),
        ('40000000-0000-0000-0000-000000000007', 1007, N'Yılın En Başarılı Sahne Tasarımı', 1007, N'Sahne Tasarımı', N'Derya Eren', NULL),
        ('40000000-0000-0000-0000-000000000008', 1008, N'Yılın En Başarılı Giysi Tasarımı', 1008, N'Giysi Tasarımı', N'Nihan Kaya', NULL),
        ('40000000-0000-0000-0000-000000000010', 1009, N'Yılın En Başarılı Sahne Müziği', 1009, N'Sahne Müziği', N'Can Erdem', NULL),
        ('40000000-0000-0000-0000-000000000009', 1010, N'Yılın En Başarılı Işık Tasarımı', 1010, N'Işık Tasarımı', N'Seda Işık', NULL),
        ('40000000-0000-0000-0000-000000000012', 1011, N'Yılın En Başarılı Hareket Düzeni (Kareografisi)', 1011, N'Hareket Düzeni', N'Mina Koç', NULL),
        ('40000000-0000-0000-0000-000000000011', 1012, N'Yılın En Başarılı Genç Kuşak Sanatçısı', 1012, N'Genç Kuşak', N'Arda Genç', NULL);

    IF EXISTS
    (
        SELECT 1
        FROM @AwardCategories AS expected
        LEFT JOIN dbo.AwardCategories AS actual
            ON actual.Id = expected.Id
           AND actual.CategoryCode = expected.CategoryCode
           AND actual.CategoryName = expected.CategoryName
           AND actual.IsPublished = 1
        WHERE actual.Id IS NULL
    )
        THROW 51101, 'AwardCategories does not match the protected reference-data contract.', 1;

    DECLARE @PlayStatuses TABLE
    (
        Id uniqueidentifier NOT NULL,
        StatusCode int NOT NULL,
        StatusName nvarchar(250) NOT NULL,
        StatusColor nvarchar(20) NOT NULL
    );

    INSERT INTO @PlayStatuses (Id, StatusCode, StatusName, StatusColor)
    VALUES
        ('30000000-0000-0000-0000-000000000001', 1, N'Oylama Aktif', N'#27ae60'),
        ('30000000-0000-0000-0000-000000000002', 2, N'Değerlendirmeyecek Oyun', N'#d9322d'),
        ('30000000-0000-0000-0000-000000000003', 3, N'Başvuru Yapmayacak Oyun', N'#2ca9e8'),
        ('30000000-0000-0000-0000-000000000004', 4, N'Sahnelenmeyecek Oyun', N'#ac48ed'),
        ('30000000-0000-0000-0000-000000000005', 5, N'Başvurusu Olmayan Oyun', N'#ffffff'),
        ('30000000-0000-0000-0000-000000000006', 6, N'Sistemde Aktif Değil', N'#ffc400');

    IF EXISTS
    (
        SELECT 1
        FROM @PlayStatuses AS expected
        LEFT JOIN dbo.PlayStatuses AS actual
            ON actual.Id = expected.Id
           AND actual.StatusCode = expected.StatusCode
           AND actual.StatusName = expected.StatusName
           AND LOWER(actual.StatusColor) = expected.StatusColor
           AND actual.IsPublished = 1
        WHERE actual.Id IS NULL
    )
        THROW 51102, 'PlayStatuses does not match the protected reference-data contract.', 1;

    CREATE TABLE #EligiblePlays
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY
    );

    INSERT INTO #EligiblePlays (Id)
    SELECT play.Id
    FROM dbo.Plays AS play
    WHERE play.StatusCode = 1
      AND play.IsPublished = 1
      AND play.RecordType = 0;

    IF NOT EXISTS (SELECT 1 FROM #EligiblePlays)
        THROW 51103, 'No published RecordType 0 play with StatusCode 1 was found.', 1;

    INSERT INTO dbo.PlayAwardCategories
        (Id, PlayId, PhotoImageId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
         IsPublished, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
    SELECT
        NEWID(),
        play.Id,
        NULL,
        SYSUTCDATETIME(),
        NULL,
        NULL,
        NULL,
        1,
        category.CurrentCandidate,
        category.CategoryCode,
        1,
        category.RoleName,
        category.RoleCode
    FROM #EligiblePlays AS play
    CROSS JOIN @AwardCategories AS category
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = play.Id
          AND existing.AwardCategoryCode = category.CategoryCode
          AND existing.RoleCode = category.RoleCode
          AND existing.IsCurrent = 1
    )
      AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = play.Id
          AND existing.AwardCategoryCode = category.CategoryCode
          AND existing.RoleCode = category.RoleCode
          AND existing.Candidate = category.CurrentCandidate
    );

    -- Add an old candidate to two acting categories so the grouped candidate
    -- dropdown and current/old labels can be tested.
    INSERT INTO dbo.PlayAwardCategories
        (Id, PlayId, PhotoImageId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
         IsPublished, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
    SELECT
        NEWID(),
        play.Id,
        NULL,
        DATEADD(day, -90, SYSUTCDATETIME()),
        NULL,
        NULL,
        NULL,
        1,
        category.OldCandidate,
        category.CategoryCode,
        0,
        category.RoleName,
        category.RoleCode
    FROM #EligiblePlays AS play
    CROSS JOIN @AwardCategories AS category
    WHERE category.OldCandidate IS NOT NULL
      AND EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS currentCandidate
          WHERE currentCandidate.PlayId = play.Id
            AND currentCandidate.AwardCategoryCode = category.CategoryCode
            AND currentCandidate.RoleCode = category.RoleCode
            AND currentCandidate.IsCurrent = 1
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS existing
          WHERE existing.PlayId = play.Id
            AND existing.AwardCategoryCode = category.CategoryCode
            AND existing.RoleCode = category.RoleCode
            AND existing.Candidate = category.OldCandidate
      );

    CREATE TABLE #EligibleJuries
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        JuryNo int NOT NULL
    );

    INSERT INTO #EligibleJuries (Id, JuryNo)
    SELECT userRecord.Id, ROW_NUMBER() OVER (ORDER BY userRecord.Id)
    FROM dbo.Users AS userRecord
    WHERE userRecord.RoleCode = 2
      AND userRecord.IsPublished = 1
      AND userRecord.IsActive = 1;

    IF NOT EXISTS (SELECT 1 FROM #EligibleJuries)
        THROW 51104, 'No active and published jury user was found.', 1;

    INSERT INTO dbo.JuryVotes
        (Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
         IsPublished, Score, JuryId)
    SELECT
        NEWID(),
        candidate.Id,
        DATEADD(minute, -(jury.JuryNo * 7), SYSUTCDATETIME()),
        jury.Id,
        NULL,
        NULL,
        1,
        1,
        jury.Id
    FROM #EligibleJuries AS jury
    CROSS JOIN dbo.PlayAwardCategories AS candidate
    INNER JOIN #EligiblePlays AS play ON play.Id = candidate.PlayId
    INNER JOIN @AwardCategories AS category
        ON category.CategoryCode = candidate.AwardCategoryCode
       AND category.RoleCode = candidate.RoleCode
    WHERE candidate.IsPublished = 1
      AND
      (
          (candidate.AwardCategoryCode IN (1003, 1004) AND candidate.IsCurrent = IIF(jury.JuryNo % 2 = 0, 1, 0))
          OR
          (candidate.AwardCategoryCode NOT IN (1003, 1004)
           AND (CHECKSUM(jury.Id, candidate.Id) & 2147483647) % 3 <> 0)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.JuryVotes AS existing
          WHERE existing.JuryId = jury.Id
            AND existing.PlayAwardCategoryId = candidate.Id
      );

    COMMIT TRANSACTION;

    SELECT N'PlayAwardCategories' AS TableName, COUNT_BIG(*) AS ActiveTestRows
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #EligiblePlays AS play ON play.Id = candidate.PlayId
    WHERE candidate.IsPublished = 1
    UNION ALL
    SELECT N'JuryVotes', COUNT_BIG(*)
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN #EligiblePlays AS play ON play.Id = candidate.PlayId
    WHERE vote.IsPublished = 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
