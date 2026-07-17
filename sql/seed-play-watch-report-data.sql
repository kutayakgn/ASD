USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Now datetime2(7) = SYSUTCDATETIME();
    DECLARE @JuryRoleId uniqueidentifier = 'e1000000-0000-0000-0000-000000000002';
    DECLARE @GroupId uniqueidentifier = 'e1100000-0000-0000-0000-000000009101';
    DECLARE @StatusId uniqueidentifier = 'e1200000-0000-0000-0000-000000009101';
    DECLARE @GroupCode int = 9101;
    DECLARE @StatusCode int = 9101;

    -- Shared lookup records. Existing records with the same codes are reused.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Roles] WHERE [RoleCode] = 2)
    BEGIN
        INSERT INTO [dbo].[Roles]
            ([Id], [RoleName], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [RoleCode])
        VALUES
            (@JuryRoleId, N'Jury', @Now, NULL, NULL, NULL, 1, 2);
    END;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Group] WHERE [Code] = @GroupCode)
    BEGIN
        INSERT INTO [dbo].[Group]
            ([Id], [Code], [GroupName], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished])
        VALUES
            (@GroupId, @GroupCode, N'Rapor Test Jürileri', @Now, NULL, NULL, NULL, 1);
    END;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[PlayStatuses] WHERE [StatusCode] = @StatusCode)
    BEGIN
        INSERT INTO [dbo].[PlayStatuses]
            ([Id], [StatusName], [StatusCode], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy],
             [IsPublished], [StatusColor])
        VALUES
            (@StatusId, N'Rapor Testi', @StatusCode, @Now, NULL, NULL, NULL, 1, N'#918150');
    END;

    DECLARE @Juries TABLE
    (
        JuryNo int NOT NULL PRIMARY KEY,
        JuryId uniqueidentifier NOT NULL
    );

    INSERT INTO @Juries ([JuryNo], [JuryId])
    SELECT
        n.N,
        CONVERT(uniqueidentifier,
            'e3000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12))
    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS n(N);

    INSERT INTO [dbo].[Users]
        ([Id], [FirstName], [LastName], [Phone], [Photo], [Username], [PasswordHash], [Email],
         [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [RoleCode], [GroupCode])
    SELECT
        j.JuryId,
        CONCAT(N'Rapor Jürisi ', j.JuryNo),
        N'Test',
        CONCAT(N'05559101', RIGHT('00' + CONVERT(varchar(2), j.JuryNo), 2)),
        NULL,
        CONCAT(N'rapor.test.juri', RIGHT('00' + CONVERT(varchar(2), j.JuryNo), 2)),
        N'TEST-HESABI-GIRIS-ICIN-DEGIL',
        CONCAT(N'rapor.test.juri', RIGHT('00' + CONVERT(varchar(2), j.JuryNo), 2), N'@afife.local'),
        @Now,
        NULL,
        NULL,
        NULL,
        1,
        2,
        @GroupCode
    FROM @Juries AS j
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[Users] AS u
        WHERE u.[Id] = j.JuryId
           OR u.[Username] = CONCAT(N'rapor.test.juri', RIGHT('00' + CONVERT(varchar(2), j.JuryNo), 2))
           OR u.[Email] = CONCAT(N'rapor.test.juri', RIGHT('00' + CONVERT(varchar(2), j.JuryNo), 2), N'@afife.local')
    );

    DECLARE @Plays TABLE
    (
        PlayNo int NOT NULL PRIMARY KEY,
        PlayId uniqueidentifier NOT NULL,
        PlayName nvarchar(255) NOT NULL,
        TargetViewCount int NOT NULL
    );

    INSERT INTO @Plays ([PlayNo], [PlayId], [PlayName], [TargetViewCount])
    SELECT
        source.PlayNo,
        CONVERT(uniqueidentifier,
            'e2000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), source.PlayNo), 12)),
        source.PlayName,
        source.TargetViewCount
    FROM
    (
        VALUES
            (1,  N'Rapor Testi - Sessiz Sokak',             1),
            (2,  N'Rapor Testi - Kırık Saatler',            2),
            (3,  N'Rapor Testi - Son Perde',                3),
            (4,  N'Rapor Testi - Uzak Bahçe',               1),
            (5,  N'Rapor Testi - Gecenin Sesi',             2),
            (6,  N'Rapor Testi - Kayıp Mektuplar',          3),
            (7,  N'Rapor Testi - Mavi Oda',                 1),
            (8,  N'Rapor Testi - Bir Yaz Akşamı',           2),
            (9,  N'Rapor Testi - Taş ve Gölge',             3),
            (10, N'Rapor Testi - Dönüş Yolu',               1),
            (11, N'Rapor Testi - Rüzgârın Ardında',         2),
            (12, N'Rapor Testi - Eski Fotoğraf',            3),
            (13, N'Rapor Testi - İstanbul Hikâyesi',        4),
            (14, N'Rapor Testi - Kırmızı Sahne',            5),
            (15, N'Rapor Testi - Zamanın İçinden',          6),
            (16, N'Rapor Testi - Bir Delinin Hatıra Defteri', 7),
            (17, N'Rapor Testi - Gökyüzüne Mektuplar',      8),
            (18, N'Rapor Testi - Aynadaki Yabancı',         4),
            (19, N'Rapor Testi - Kıyıda Bekleyenler',       5),
            (20, N'Rapor Testi - Küçük Bir Umut',           6),
            (21, N'Rapor Testi - Beyaz Geceler',            7),
            (22, N'Rapor Testi - İçimizdeki Deniz',         8),
            (23, N'Rapor Testi - Sonbahar Şarkısı',         4),
            (24, N'Rapor Testi - Yolun Sonundaki Ev',       5)
    ) AS source(PlayNo, PlayName, TargetViewCount);

    INSERT INTO [dbo].[Plays]
        ([Id], [PlayName], [StatusCode], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy],
         [IsPublished], [Slug], [TheaterName], [Phone], [ContactPersonName], [ContactPersonPhone],
         [Address], [Email], [FromKunye])
    SELECT
        p.PlayId,
        p.PlayName,
        @StatusCode,
        DATEADD(minute, -p.PlayNo, @Now),
        NULL,
        NULL,
        NULL,
        1,
        CONCAT('rapor-test-oyunu-', RIGHT('00' + CONVERT(varchar(2), p.PlayNo), 2)),
        'Afife Test Sahnesi',
        '02129100000',
        'Afife Test Ekibi',
        '05329100000',
        'Istanbul',
        CONCAT('rapor-oyun-', RIGHT('00' + CONVERT(varchar(2), p.PlayNo), 2), '@afife.local'),
        0
    FROM @Plays AS p
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[Plays] AS existing
        WHERE existing.[Id] = p.PlayId
           OR existing.[Slug] = CONCAT('rapor-test-oyunu-', RIGHT('00' + CONVERT(varchar(2), p.PlayNo), 2))
    );

    -- A ticket row means that the jury member watched the play. The unique
    -- (UserId, PlayId) constraint is respected and reruns do not duplicate rows.
    INSERT INTO [dbo].[JuryGameTicketFees]
        ([Id], [UserId], [PlayId], [TicketFee], [CreatedAt], [CreatedBy],
         [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT
        NEWID(),
        j.JuryId,
        p.PlayId,
        CONVERT(decimal(10, 2), 180 + (p.PlayNo * 5) + (j.JuryNo * 2.5)),
        DATEADD(minute, -(p.PlayNo + j.JuryNo), @Now),
        NULL,
        NULL,
        NULL,
        1
    FROM @Plays AS p
    INNER JOIN [dbo].[Plays] AS existingPlay ON existingPlay.[Id] = p.PlayId
    INNER JOIN @Juries AS j ON j.JuryNo <= p.TargetViewCount
    INNER JOIN [dbo].[Users] AS existingJury ON existingJury.[Id] = j.JuryId
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[JuryGameTicketFees] AS fee
        WHERE fee.[UserId] = j.JuryId
          AND fee.[PlayId] = p.PlayId
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Verification uses the same unique-viewer rule as PlayWatchReportService.
;WITH [UniqueViewers] AS
(
    SELECT [PlayId], [UserId]
    FROM [dbo].[JuryGameTicketFees]
    WHERE [IsPublished] = 1

    UNION

    SELECT pac.[PlayId], vote.[JuryId]
    FROM [dbo].[JuryVotes] AS vote
    INNER JOIN [dbo].[PlayAwardCategories] AS pac
        ON pac.[Id] = vote.[PlayAwardCategoryId]
    WHERE vote.[IsPublished] = 1
      AND pac.[IsPublished] = 1
),
[ReportRows] AS
(
    SELECT
        play.[Id],
        play.[PlayName],
        COUNT(viewer.[UserId]) AS [UniqueViewCount]
    FROM [dbo].[Plays] AS play
    LEFT JOIN [UniqueViewers] AS viewer ON viewer.[PlayId] = play.[Id]
    WHERE play.[IsPublished] = 1
      AND play.[Slug] LIKE 'rapor-test-oyunu-%'
    GROUP BY play.[Id], play.[PlayName]
)
SELECT
    [PlayName] AS [Oyun],
    [UniqueViewCount] AS [TekilIzlenme],
    CASE
        WHEN [UniqueViewCount] < 4 THEN N'4''ten az izlenenler'
        ELSE N'4 kez ve üzeri izlenenler'
    END AS [Tab]
FROM [ReportRows]
ORDER BY
    CASE WHEN [UniqueViewCount] < 4 THEN 0 ELSE 1 END,
    [UniqueViewCount],
    [PlayName];
GO
