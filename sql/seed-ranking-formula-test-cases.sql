SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CorrelationId uniqueidentifier = NEWID();
EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @CorrelationId;
EXEC sys.sp_set_session_context @key = N'AdminUsername', @value = N'codex-test-seed';
EXEC sys.sp_set_session_context @key = N'AdminOperationName', @value = N'SeedRankingFormulaTestCases';
EXEC sys.sp_set_session_context @key = N'AdminApplication', @value = N'AfifeAdmin SQL Test Seed';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Now datetime2 = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @PlayId uniqueidentifier = '60000000-0000-0000-0000-000000000004';
    DECLARE @FirstCandidateId uniqueidentifier = '93d12343-fcdb-4adc-af14-57f47ba6e71c';
    DECLARE @SecondCandidateId uniqueidentifier = 'd5e4e597-f12e-40ad-b55b-9b9e28ba104c';
    DECLARE @PasswordHash nvarchar(500) =
        N'6n94xLRj/2ixxzXM5pa9n1vFybA79tb+6+AasgDgz1JHPjne';

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Plays
        WHERE Id = @PlayId
          AND RecordType = 0
          AND IsPublished = 1
    )
        THROW 52300, N'Kon Perdes test oyunu uygun durumda bulunamadı.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories
        WHERE Id = @FirstCandidateId
          AND PlayId = @PlayId
          AND AwardCategoryCode = 1001
          AND IsCurrent = 1
          AND IsActive = 1
          AND IsPublished = 1
    )
        THROW 52301, N'Puan Testi 1 için kategori 1001 kaydı uygun durumda bulunamadı.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories
        WHERE Id = @SecondCandidateId
          AND PlayId = @PlayId
          AND AwardCategoryCode = 1006
          AND IsCurrent = 1
          AND IsActive = 1
          AND IsPublished = 1
    )
        THROW 52302, N'Puan Testi 2 için kategori 1006 kaydı uygun durumda bulunamadı.', 1;

    DECLARE @Scores TABLE
    (
        TestNo tinyint NOT NULL,
        JuryNo int NOT NULL,
        Score int NOT NULL,
        PRIMARY KEY (TestNo, JuryNo)
    );

    INSERT INTO @Scores (TestNo, JuryNo, Score)
    VALUES
        (1, 1, 5), (1, 2, 7), (1, 3, 6), (1, 4, 9),
        (1, 5, 8), (1, 6, 4), (1, 7, 6), (1, 8, 3),
        (1, 9, 2), (1, 10, 6), (1, 11, 3), (1, 12, 7),
        (1, 13, 5), (1, 14, 8), (1, 15, 8), (1, 16, 9),
        (1, 17, 9), (1, 18, 6), (1, 19, 4), (1, 20, 9),
        (1, 21, 7), (1, 22, 10), (1, 23, 8), (1, 24, 7),
        (1, 25, 6), (1, 26, 8), (1, 27, 9), (1, 28, 2),
        (1, 29, 6), (1, 30, 6), (1, 31, 2), (1, 32, 6),
        (2, 1, 2), (2, 2, 3), (2, 3, 5), (2, 4, 4),
        (2, 5, 3), (2, 6, 9), (2, 7, 8), (2, 8, 8),
        (2, 9, 4), (2, 10, 7), (2, 11, 2), (2, 12, 6),
        (2, 13, 7), (2, 14, 6), (2, 15, 7), (2, 16, 3),
        (2, 17, 3), (2, 18, 8), (2, 19, 7), (2, 20, 7),
        (2, 21, 3), (2, 22, 9), (2, 23, 8), (2, 24, 7),
        (2, 25, 4), (2, 26, 6), (2, 27, 6), (2, 28, 9),
        (2, 29, 7), (2, 30, 4), (2, 31, 6), (2, 32, 5),
        (2, 33, 9);

    DECLARE @TestJuries TABLE
    (
        JuryNo int NOT NULL PRIMARY KEY,
        JuryId uniqueidentifier NOT NULL,
        Username nvarchar(100) NOT NULL,
        Email nvarchar(255) NOT NULL
    );

    ;WITH Numbers AS
    (
        SELECT 1 AS JuryNo
        UNION ALL
        SELECT JuryNo + 1
        FROM Numbers
        WHERE JuryNo < 33
    )
    INSERT INTO @TestJuries (JuryNo, JuryId, Username, Email)
    SELECT
        JuryNo,
        CONVERT
        (
            uniqueidentifier,
            CONCAT
            (
                N'91000000-0000-0000-0000-',
                RIGHT(N'000000000000' + CONVERT(nvarchar(12), JuryNo), 12)
            )
        ),
        CONCAT(N'puan.test.juri.', RIGHT(N'00' + CONVERT(nvarchar(2), JuryNo), 2)),
        CONCAT
        (
            N'puan.test.juri.',
            RIGHT(N'00' + CONVERT(nvarchar(2), JuryNo), 2),
            N'@afife.test'
        )
    FROM Numbers
    OPTION (MAXRECURSION 33);

    IF EXISTS
    (
        SELECT 1
        FROM @TestJuries AS expected
        INNER JOIN dbo.Users AS actual
            ON
            (
                actual.Username = expected.Username
                OR actual.Email = expected.Email
            )
           AND actual.RoleCode = 2
           AND actual.IsPublished = 1
        WHERE actual.Id <> expected.JuryId
    )
        THROW 52303, N'Test jüri kullanıcı adı veya e-posta değerlerinden biri başka bir aktif kayıtta kullanılıyor.', 1;

    UPDATE actual
    SET
        FirstName = N'Puan Testi',
        LastName = CONCAT(N'Jüri ', RIGHT(N'00' + CONVERT(nvarchar(2), expected.JuryNo), 2)),
        Phone = CONCAT(N'0500000', RIGHT(N'0000' + CONVERT(nvarchar(4), expected.JuryNo), 4)),
        Username = expected.Username,
        PasswordHash = @PasswordHash,
        Email = expected.Email,
        UpdatedAt = @Now,
        UpdatedBy = NULL,
        IsPublished = 1,
        RoleCode = 2,
        GroupCode = NULL,
        PhotoImageId = NULL,
        IsActive = 1
    FROM dbo.Users AS actual
    INNER JOIN @TestJuries AS expected ON expected.JuryId = actual.Id
    WHERE actual.FirstName <> N'Puan Testi'
       OR actual.LastName <>
            CONCAT(N'Jüri ', RIGHT(N'00' + CONVERT(nvarchar(2), expected.JuryNo), 2))
       OR COALESCE(actual.Phone, N'') <>
            CONCAT(N'0500000', RIGHT(N'0000' + CONVERT(nvarchar(4), expected.JuryNo), 4))
       OR actual.Username <> expected.Username
       OR actual.PasswordHash <> @PasswordHash
       OR actual.Email <> expected.Email
       OR actual.IsPublished <> 1
       OR actual.RoleCode <> 2
       OR actual.GroupCode IS NOT NULL
       OR actual.PhotoImageId IS NOT NULL
       OR actual.IsActive <> 1;

    INSERT INTO dbo.Users
    (
        Id,
        FirstName,
        LastName,
        Phone,
        Username,
        PasswordHash,
        Email,
        CreatedAt,
        CreatedBy,
        UpdatedAt,
        UpdatedBy,
        IsPublished,
        RoleCode,
        GroupCode,
        PhotoImageId,
        IsActive
    )
    SELECT
        expected.JuryId,
        N'Puan Testi',
        CONCAT(N'Jüri ', RIGHT(N'00' + CONVERT(nvarchar(2), expected.JuryNo), 2)),
        CONCAT(N'0500000', RIGHT(N'0000' + CONVERT(nvarchar(4), expected.JuryNo), 4)),
        expected.Username,
        @PasswordHash,
        expected.Email,
        @Now,
        NULL,
        NULL,
        NULL,
        1,
        2,
        NULL,
        NULL,
        1
    FROM @TestJuries AS expected
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Users AS actual
        WHERE actual.Id = expected.JuryId
    );

    DECLARE @ExpectedVotes TABLE
    (
        VoteId uniqueidentifier NOT NULL PRIMARY KEY,
        PlayAwardCategoryId uniqueidentifier NOT NULL,
        JuryId uniqueidentifier NOT NULL,
        Score int NOT NULL
    );

    INSERT INTO @ExpectedVotes (VoteId, PlayAwardCategoryId, JuryId, Score)
    SELECT
        CONVERT
        (
            uniqueidentifier,
            CONCAT
            (
                CASE scores.TestNo WHEN 1
                    THEN N'92000000-0000-0000-0000-'
                    ELSE N'93000000-0000-0000-0000-'
                END,
                RIGHT(N'000000000000' + CONVERT(nvarchar(12), scores.JuryNo), 12)
            )
        ),
        CASE scores.TestNo
            WHEN 1 THEN @FirstCandidateId
            ELSE @SecondCandidateId
        END,
        jury.JuryId,
        scores.Score
    FROM @Scores AS scores
    INNER JOIN @TestJuries AS jury ON jury.JuryNo = scores.JuryNo;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.JuryVotes AS vote
        WHERE vote.PlayAwardCategoryId IN (@FirstCandidateId, @SecondCandidateId)
          AND vote.IsPublished = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM @ExpectedVotes AS expected
              WHERE expected.VoteId = vote.Id
          )
    )
        THROW 52304, N'Test kategorilerinden birinde test senaryosu dışında aktif oy bulundu.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedVotes AS expected
        INNER JOIN dbo.JuryVotes AS actual ON actual.Id = expected.VoteId
        WHERE actual.JuryId <> expected.JuryId
           OR actual.PlayAwardCategoryId <> expected.PlayAwardCategoryId
    )
        THROW 52305, N'Test oy GUID alanı başka bir oy kaydı tarafından kullanılıyor.', 1;

    UPDATE actual
    SET
        Score = expected.Score,
        UpdatedAt = @Now,
        UpdatedBy = NULL,
        IsPublished = 1,
        IsActive = 1
    FROM dbo.JuryVotes AS actual
    INNER JOIN @ExpectedVotes AS expected ON expected.VoteId = actual.Id
    WHERE actual.Score <> expected.Score
       OR actual.IsPublished <> 1
       OR actual.IsActive <> 1;

    INSERT INTO dbo.JuryVotes
    (
        Id,
        PlayAwardCategoryId,
        CreatedAt,
        CreatedBy,
        UpdatedAt,
        UpdatedBy,
        IsPublished,
        Score,
        JuryId,
        IsActive
    )
    SELECT
        expected.VoteId,
        expected.PlayAwardCategoryId,
        DATEADD(MINUTE, expected.Score, @Now),
        expected.JuryId,
        NULL,
        NULL,
        1,
        expected.Score,
        expected.JuryId,
        1
    FROM @ExpectedVotes AS expected
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.JuryVotes AS actual
        WHERE actual.Id = expected.VoteId
    );

    EXEC dbo.usp_RefreshRankings;

    DECLARE @ExpectedResults TABLE
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        VoteCount int NOT NULL,
        ArithmeticMean float NOT NULL,
        SampleVariance float NOT NULL,
        TrimmedMean float NOT NULL,
        ConfidenceValue int NOT NULL
    );

    INSERT INTO @ExpectedResults
        (CandidateId, VoteCount, ArithmeticMean, SampleVariance, TrimmedMean, ConfidenceValue)
    VALUES
        (@FirstCandidateId, 32, 6.28125, 5.11189516129032, 6.3, 2),
        (@SecondCandidateId, 33, 5.81818181818182, 4.77840909090909, 5.83870967741935, 3);

    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedResults AS expected
        LEFT JOIN dbo.Rankings AS actual
            ON actual.PlayAwardCategoryId = expected.CandidateId
           AND actual.IsPublished = 1
        WHERE actual.Id IS NULL
           OR actual.NumberOfActiveVote <> expected.VoteCount
           OR ABS(actual.ArithmeticMean - expected.ArithmeticMean) > 0.000000001
           OR ABS(actual.ArithmeticVariance - expected.SampleVariance) > 0.000000001
           OR ABS(actual.TrimmedMean - expected.TrimmedMean) > 0.000000001
           OR actual.ConfidenceValue <> expected.ConfidenceValue
    )
        THROW 52306, N'Rankings projeksiyonu beklenen test sonuçlarını üretmedi.', 1;

    COMMIT TRANSACTION;

    SELECT
        play.PlayName,
        category.CategoryName,
        candidate.Candidate,
        ranking.NumberOfActiveVote,
        ranking.ArithmeticMean,
        ranking.ArithmeticVariance,
        ranking.TrimmedMean,
        ranking.ConfidenceValue
    FROM dbo.Rankings AS ranking
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = ranking.PlayAwardCategoryId
    INNER JOIN dbo.Plays AS play ON play.Id = ranking.PlayId
    INNER JOIN dbo.AwardCategories AS category
        ON category.CategoryCode = candidate.AwardCategoryCode
    WHERE ranking.PlayAwardCategoryId IN (@FirstCandidateId, @SecondCandidateId)
      AND ranking.IsPublished = 1
    ORDER BY candidate.AwardCategoryCode;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminUsername', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminOperationName', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminApplication', @value = NULL;
    THROW;
END CATCH;

EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
EXEC sys.sp_set_session_context @key = N'AdminUsername', @value = NULL;
EXEC sys.sp_set_session_context @key = N'AdminOperationName', @value = NULL;
EXEC sys.sp_set_session_context @key = N'AdminApplication', @value = NULL;
