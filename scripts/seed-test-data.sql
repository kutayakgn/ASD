/*
    YKBAfife test data seed

    Safety:
      1. Set @ExpectedDatabaseName to the exact test database name.
      2. Set @AllowTestData to 1.
      3. Never run this file against production.

    The script is idempotent for the records it owns. AwardCategories and
    PlayStatuses are immutable shared contracts, so they are validated but never
    inserted, updated, or deleted here.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabaseName sysname = N'AfifeAdmin_Test';
DECLARE @AllowTestData bit = 0;

IF @AllowTestData <> 1
    THROW 54000, N'Test verisi eklemek için @AllowTestData değerini 1 yapın.', 1;

IF DB_NAME() <> @ExpectedDatabaseName
    THROW 54001, N'Bağlı veritabanı @ExpectedDatabaseName ile eşleşmiyor. İşlem durduruldu.', 1;

IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
    THROW 54002, N'Önce uygulamayı çalıştırarak EF migration işlemlerini tamamlayın.', 1;

IF EXISTS
(
    SELECT MigrationId
    FROM (VALUES
        (N'20260803125913_InitialManagedBaseline'),
        (N'20260803132846_PreserveLegacyFormMapping')
    ) expected(MigrationId)
    EXCEPT
    SELECT MigrationId FROM dbo.__EFMigrationsHistory
)
    THROW 54003, N'Beklenen EF migration sürümleri uygulanmamış. Seed işlemi durduruldu.', 1;

DECLARE @ReferenceCreatedAt datetime2(7) = '2026-07-16T15:39:19.4137221';
DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
DECLARE @AdminId uniqueidentifier = '50000000-0000-0000-0000-000000000001';
DECLARE @PasswordHash nvarchar(500) = N'oDajqYzI1FXAP9N3WLa2B4PNn0pYLTdgy52ZUCsOQ7k/EiYF';

DECLARE @ExpectedAwardCategories TABLE
(
    Id uniqueidentifier NOT NULL,
    CategoryName nvarchar(255) NOT NULL,
    CategoryCode int NOT NULL,
    IsPublished bit NOT NULL,
    MultiCandidate bit NOT NULL,
    HasRoleAndPhoto bit NOT NULL
);

INSERT INTO @ExpectedAwardCategories
    (Id, CategoryName, CategoryCode, IsPublished, MultiCandidate, HasRoleAndPhoto)
VALUES
('40000000-0000-0000-0000-000000000001', N'Yılın En Başarılı Oyunu', 1001, 1, 0, 0),
('40000000-0000-0000-0000-000000000002', N'Yılın En Başarılı Yönetmeni', 1002, 1, 0, 1),
('40000000-0000-0000-0000-000000000003', N'Yılın En Başarılı Kadın Oyuncusu', 1003, 1, 1, 1),
('40000000-0000-0000-0000-000000000004', N'Yılın En Başarılı Erkek Oyuncusu', 1004, 1, 1, 1),
('40000000-0000-0000-0000-000000000005', N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', 1005, 1, 1, 1),
('40000000-0000-0000-0000-000000000006', N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', 1006, 1, 1, 1),
('40000000-0000-0000-0000-000000000007', N'Yılın En Başarılı Sahne Tasarımı', 1007, 1, 0, 0),
('40000000-0000-0000-0000-000000000008', N'Yılın En Başarılı Giysi Tasarımı', 1008, 1, 0, 0),
('40000000-0000-0000-0000-000000000009', N'Yılın En Başarılı Işık Tasarımı', 1010, 1, 0, 0),
('40000000-0000-0000-0000-000000000010', N'Yılın En Başarılı Sahne Müziği', 1009, 1, 0, 0),
('40000000-0000-0000-0000-000000000011', N'Yılın En Başarılı Genç Kuşak Sanatçısı', 1012, 1, 1, 1),
('40000000-0000-0000-0000-000000000012', N'Yılın En Başarılı Hareket Düzeni (Kareografisi)', 1011, 1, 0, 0);

IF EXISTS
(
    SELECT Id, CategoryName COLLATE Latin1_General_100_BIN2, CategoryCode,
           IsPublished, MultiCandidate, HasRoleAndPhoto
    FROM @ExpectedAwardCategories
    EXCEPT
    SELECT Id, CategoryName COLLATE Latin1_General_100_BIN2, CategoryCode,
           IsPublished, MultiCandidate, HasRoleAndPhoto
    FROM dbo.AwardCategories
)
OR EXISTS
(
    SELECT Id, CategoryName COLLATE Latin1_General_100_BIN2, CategoryCode,
           IsPublished, MultiCandidate, HasRoleAndPhoto
    FROM dbo.AwardCategories
    WHERE CategoryCode BETWEEN 1001 AND 1012
    EXCEPT
    SELECT Id, CategoryName COLLATE Latin1_General_100_BIN2, CategoryCode,
           IsPublished, MultiCandidate, HasRoleAndPhoto
    FROM @ExpectedAwardCategories
)
    THROW 54004, N'AwardCategories ortak referans sözleşmesi beklenen değerlerle uyuşmuyor.', 1;

DECLARE @ExpectedPlayStatuses TABLE
(
    Id uniqueidentifier NOT NULL,
    StatusName nvarchar(100) NOT NULL,
    StatusCode int NOT NULL,
    IsPublished bit NOT NULL,
    StatusColor nvarchar(50) NOT NULL
);

INSERT INTO @ExpectedPlayStatuses (Id, StatusName, StatusCode, IsPublished, StatusColor)
VALUES
('30000000-0000-0000-0000-000000000001', N'Oylama Aktif', 1, 1, N'#27ae60'),
('30000000-0000-0000-0000-000000000002', N'Değerlendirmeyecek Oyun', 2, 1, N'#d9322d'),
('30000000-0000-0000-0000-000000000003', N'Başvuru Yapmayacak Oyun', 3, 1, N'#2CA9E8'),
('30000000-0000-0000-0000-000000000004', N'Sahnelenmeyecek Oyun', 4, 1, N'#ac48ed'),
('30000000-0000-0000-0000-000000000005', N'Başvurusu Olmayan Oyun', 5, 1, N'#ffffff'),
('30000000-0000-0000-0000-000000000006', N'Sistemde Aktif Değil', 6, 1, N'#ffc400');

IF EXISTS
(
    SELECT Id, StatusName COLLATE Latin1_General_100_BIN2, StatusCode,
           IsPublished, StatusColor COLLATE Latin1_General_100_BIN2
    FROM @ExpectedPlayStatuses
    EXCEPT
    SELECT Id, StatusName COLLATE Latin1_General_100_BIN2, StatusCode,
           IsPublished, StatusColor COLLATE Latin1_General_100_BIN2
    FROM dbo.PlayStatuses
)
OR EXISTS
(
    SELECT Id, StatusName COLLATE Latin1_General_100_BIN2, StatusCode,
           IsPublished, StatusColor COLLATE Latin1_General_100_BIN2
    FROM dbo.PlayStatuses
    WHERE StatusCode BETWEEN 1 AND 6
    EXCEPT
    SELECT Id, StatusName COLLATE Latin1_General_100_BIN2, StatusCode,
           IsPublished, StatusColor COLLATE Latin1_General_100_BIN2
    FROM @ExpectedPlayStatuses
)
    THROW 54005, N'PlayStatuses ortak referans sözleşmesi beklenen değerlerle uyuşmuyor.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=N'00000000-0000-0000-0000-000000005eed';
    EXEC sys.sp_set_session_context @key=N'AdminUserId', @value=N'50000000-0000-0000-0000-000000000001';
    EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=N'test-seed';
    EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=N'Test veri kurulumu';
    EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=N'AfifeAdmin.TestSeed';

    MERGE dbo.Roles WITH (HOLDLOCK) AS target
    USING (VALUES
        (CONVERT(uniqueidentifier, '10000000-0000-0000-0000-000000000001'), N'Koordinatör', 1),
        (CONVERT(uniqueidentifier, '10000000-0000-0000-0000-000000000002'), N'Jüri', 2)
    ) AS source(Id, RoleName, RoleCode)
    ON target.RoleCode = source.RoleCode
    WHEN MATCHED THEN UPDATE SET
        target.RoleName = source.RoleName,
        target.IsPublished = 1
    WHEN NOT MATCHED THEN INSERT
        (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
        VALUES (source.Id, source.RoleName, @ReferenceCreatedAt, NULL, NULL, NULL, 1, source.RoleCode);

    MERGE dbo.[Group] WITH (HOLDLOCK) AS target
    USING (VALUES
        (CONVERT(uniqueidentifier, '60000000-0000-0000-0000-000000000001'), 1, N'Grup 1'),
        (CONVERT(uniqueidentifier, '60000000-0000-0000-0000-000000000002'), 2, N'Grup 2'),
        (CONVERT(uniqueidentifier, '60000000-0000-0000-0000-000000000003'), 3, N'Grup 3')
    ) AS source(Id, Code, GroupName)
    ON target.Code = source.Code
    WHEN MATCHED THEN UPDATE SET target.GroupName = source.GroupName, target.IsPublished = 1
    WHEN NOT MATCHED THEN INSERT
        (Id, Code, GroupName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished)
        VALUES (source.Id, source.Code, source.GroupName, @Now, @AdminId, NULL, NULL, 1);

    IF EXISTS
    (
        SELECT 1 FROM dbo.Users
        WHERE IsPublished = 1 AND RoleCode = 1
          AND (Username = N'admin' OR Email = N'kutaya.akgun@ykteknoloji.com.tr')
          AND Id <> @AdminId
    )
        THROW 54006, N'admin kullanıcı adı veya Kutay e-posta adresi başka bir koordinatör kaydında kullanılıyor.', 1;

    MERGE dbo.Users WITH (HOLDLOCK) AS target
    USING (SELECT @AdminId AS Id) AS source
    ON target.Id = source.Id
    WHEN MATCHED THEN UPDATE SET
        FirstName = N'Kutay', LastName = N'Akgün', Phone = N'5550000001',
        Username = N'admin', PasswordHash = @PasswordHash,
        Email = N'kutaya.akgun@ykteknoloji.com.tr',
        CreatedAt = '2026-07-16T15:39:19.4137221', CreatedBy = NULL,
        UpdatedAt = '2026-07-22T12:03:18.7412401', UpdatedBy = @AdminId,
        IsPublished = 1, RoleCode = 1, GroupCode = NULL,
        PhotoImageId = NULL, IsActive = 1
    WHEN NOT MATCHED THEN INSERT
        (Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
         CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode,
         GroupCode, PhotoImageId, IsActive)
        VALUES
        (@AdminId, N'Kutay', N'Akgün', N'5550000001', N'admin', @PasswordHash,
         N'kutaya.akgun@ykteknoloji.com.tr', '2026-07-16T15:39:19.4137221', NULL,
         '2026-07-22T12:03:18.7412401', @AdminId, 1, 1, NULL, NULL, 1);

    DECLARE @Juries TABLE
    (
        Id uniqueidentifier NOT NULL,
        FirstName nvarchar(100) NOT NULL,
        LastName nvarchar(100) NOT NULL,
        Username nvarchar(100) NOT NULL,
        Email nvarchar(255) NOT NULL,
        Phone nvarchar(30) NOT NULL,
        GroupCode int NULL
    );

    INSERT INTO @Juries VALUES
    ('51000000-0000-0000-0000-000000000001', N'Aylin', N'Yılmaz', N'juri01', N'juri01@afife.test', N'5551000001', 1),
    ('51000000-0000-0000-0000-000000000002', N'Barış', N'Demir', N'juri02', N'juri02@afife.test', N'5551000002', 1),
    ('51000000-0000-0000-0000-000000000003', N'Ceren', N'Kaya', N'juri03', N'juri03@afife.test', N'5551000003', 1),
    ('51000000-0000-0000-0000-000000000004', N'Deniz', N'Arslan', N'juri04', N'juri04@afife.test', N'5551000004', 1),
    ('51000000-0000-0000-0000-000000000005', N'Ece', N'Çelik', N'juri05', N'juri05@afife.test', N'5551000005', 2),
    ('51000000-0000-0000-0000-000000000006', N'Fırat', N'Şahin', N'juri06', N'juri06@afife.test', N'5551000006', 2),
    ('51000000-0000-0000-0000-000000000007', N'Gül', N'Aksoy', N'juri07', N'juri07@afife.test', N'5551000007', 2),
    ('51000000-0000-0000-0000-000000000008', N'Hakan', N'Koç', N'juri08', N'juri08@afife.test', N'5551000008', 2),
    ('51000000-0000-0000-0000-000000000009', N'İpek', N'Aydın', N'juri09', N'juri09@afife.test', N'5551000009', 3),
    ('51000000-0000-0000-0000-000000000010', N'Kerem', N'Öztürk', N'juri10', N'juri10@afife.test', N'5551000010', 3),
    ('51000000-0000-0000-0000-000000000011', N'Lale', N'Ergin', N'juri11', N'juri11@afife.test', N'5551000011', NULL),
    ('51000000-0000-0000-0000-000000000012', N'Mert', N'Güneş', N'juri12', N'juri12@afife.test', N'5551000012', NULL);

    IF EXISTS
    (
        SELECT 1
        FROM @Juries source
        INNER JOIN dbo.Users target
            ON target.IsPublished = 1 AND target.RoleCode = 2
           AND (target.Username = source.Username OR target.Email = source.Email)
           AND target.Id <> source.Id
    )
        THROW 54007, N'Test jüri kullanıcı adı veya e-posta değerlerinden biri başka kayıtta kullanılıyor.', 1;

    MERGE dbo.Users WITH (HOLDLOCK) AS target
    USING @Juries AS source ON target.Id = source.Id
    WHEN MATCHED THEN UPDATE SET
        FirstName = source.FirstName, LastName = source.LastName, Phone = source.Phone,
        Username = source.Username, PasswordHash = @PasswordHash, Email = source.Email,
        IsPublished = 1, IsActive = 1, RoleCode = 2, GroupCode = source.GroupCode,
        UpdatedAt = @Now, UpdatedBy = @AdminId
    WHEN NOT MATCHED THEN INSERT
        (Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
         CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode,
         GroupCode, PhotoImageId, IsActive)
        VALUES
        (source.Id, source.FirstName, source.LastName, source.Phone, source.Username,
         @PasswordHash, source.Email, @Now, @AdminId, NULL, NULL, 1, 2,
         source.GroupCode, NULL, 1);

    MERGE dbo.Announcements WITH (HOLDLOCK) AS target
    USING (VALUES
        (CONVERT(uniqueidentifier, 'B0000000-0000-0000-0000-000000000001'), 1,
         N'Duyuru metni 1', N'Detayları Gör', N'/announcements/test-1'),
        (CONVERT(uniqueidentifier, 'B0000000-0000-0000-0000-000000000002'), 2,
         N'Duyuru metni 2', N'Detayları Gör', N'/announcements/test-2')
    ) AS source(Id, AnnouncementLocationId, [Text], ButtonText, ButtonLink)
    ON target.Id = source.Id
    WHEN MATCHED THEN UPDATE SET
        AnnouncementLocationId = source.AnnouncementLocationId,
        [Text] = source.[Text], ButtonText = source.ButtonText,
        ButtonLink = source.ButtonLink, BackgroundColor = N'#F5F1E8',
        CreatedAt = @ReferenceCreatedAt,
        CreatedBy = '10000000-0000-0000-0000-000000000001',
        UpdatedAt = NULL, UpdatedBy = NULL, IsPublished = 1,
        ImageId = NULL, BackgroundImageId = NULL
    WHEN NOT MATCHED THEN INSERT
        (Id, AnnouncementLocationId, [Text], ButtonText, ButtonLink,
         BackgroundColor, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
         IsPublished, ImageId, BackgroundImageId)
        VALUES
        (source.Id, source.AnnouncementLocationId, source.[Text], source.ButtonText,
         source.ButtonLink, N'#F5F1E8', @ReferenceCreatedAt,
         '10000000-0000-0000-0000-000000000001', NULL, NULL, 1, NULL, NULL);

    DECLARE @Plays TABLE
    (
        Id uniqueidentifier NOT NULL,
        PlayName nvarchar(255) NOT NULL,
        TheaterName nvarchar(255) NOT NULL,
        Slug varchar(255) NOT NULL,
        StatusCode int NOT NULL,
        RecordType bit NOT NULL
    );

    INSERT INTO @Plays VALUES
    ('70000000-0000-0000-0000-000000000001', N'Kayıp Zamanın İzinde', N'İstanbul Sahne', 'kayip-zamanin-izinde', 1, 0),
    ('70000000-0000-0000-0000-000000000002', N'Bir Yaz Gecesi', N'Ankara Sanat Tiyatrosu', 'bir-yaz-gecesi', 1, 0),
    ('70000000-0000-0000-0000-000000000003', N'Gölgeler Arasında', N'İzmir Kent Tiyatrosu', 'golgeler-arasinda', 1, 0),
    ('70000000-0000-0000-0000-000000000004', N'Son Perde', N'Bursa Şehir Tiyatrosu', 'son-perde', 1, 0),
    ('70000000-0000-0000-0000-000000000005', N'Kırık Saatler', N'Kadıköy Sahne', 'kirik-saatler', 1, 0),
    ('70000000-0000-0000-0000-000000000006', N'Rüzgarın Sesi', N'Bakırköy Tiyatrosu', 'ruzgarin-sesi', 1, 0),
    ('70000000-0000-0000-0000-000000000007', N'Biletli Hatıralar', N'Afife Test Sahnesi', 'biletli-hatiralar', 2, 1),
    ('70000000-0000-0000-0000-000000000008', N'Sessiz Koridor', N'Afife Test Sahnesi', 'sessiz-koridor', 3, 1),
    ('70000000-0000-0000-0000-000000000009', N'Gece Treni', N'Afife Test Sahnesi', 'gece-treni', 4, 1),
    ('70000000-0000-0000-0000-000000000010', N'Uzak Sahne', N'Afife Test Sahnesi', 'uzak-sahne', 6, 1);

    IF EXISTS
    (
        SELECT 1 FROM @Plays source
        INNER JOIN dbo.Plays target ON target.IsPublished = 1 AND target.Slug = source.Slug
        WHERE target.Id <> source.Id
    )
        THROW 54008, N'Test oyunlarından birinin slug değeri başka bir oyun tarafından kullanılıyor.', 1;

    INSERT INTO dbo.Plays
    (
        Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, Slug, TheaterName, Phone, ContactPersonName,
        ContactPersonPhone, Address, Email, JuriOylamaStatus,
        KunyeGirisStatus, RecordType, SourceFormId, IsActive
    )
    SELECT source.Id, source.PlayName, source.StatusCode,
           DATEADD(DAY, -ROW_NUMBER() OVER (ORDER BY source.Id), @Now), @AdminId,
           NULL, NULL, 1, source.Slug, source.TheaterName, N'02120000000',
           N'Test İletişim', N'5552000000', N'İstanbul',
           N'oyun@afife.test',
           CASE WHEN source.RecordType = 0 THEN 1 ELSE 0 END,
           CASE WHEN source.RecordType = 0 THEN 1 ELSE 0 END,
           source.RecordType, NULL, 1
    FROM @Plays source
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Plays target WHERE target.Id = source.Id);

    DECLARE @Candidates TABLE
    (
        Id uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        [Role] nvarchar(200) NULL,
        RoleCode int NOT NULL,
        IsCurrent bit NOT NULL
    );

    INSERT INTO @Candidates VALUES
    ('80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 1002, N'Selin Akman', NULL, 0, 1),
    ('80000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000001', 1004, N'Ahmet Kaya', N'Kemal', 102, 0),
    ('80000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000001', 1004, N'Hüseyin Demir', N'Kemal', 102, 1),
    ('80000000-0000-0000-0000-000000000004', '70000000-0000-0000-0000-000000000002', 1002, N'Zeynep Arı', NULL, 0, 1),
    ('80000000-0000-0000-0000-000000000005', '70000000-0000-0000-0000-000000000002', 1003, N'Derya Yalçın', N'Helena', 202, 1),
    ('80000000-0000-0000-0000-000000000006', '70000000-0000-0000-0000-000000000003', 1002, N'Murat Eren', NULL, 0, 1),
    ('80000000-0000-0000-0000-000000000007', '70000000-0000-0000-0000-000000000003', 1005, N'Elif Özer', N'Leyla', 302, 1),
    ('80000000-0000-0000-0000-000000000008', '70000000-0000-0000-0000-000000000004', 1002, N'Can Uslu', NULL, 0, 1),
    ('80000000-0000-0000-0000-000000000009', '70000000-0000-0000-0000-000000000005', 1007, N'Pelin Işık', NULL, 0, 1),
    ('80000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000006', 1009, N'Emre Ses', NULL, 0, 1);

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        Candidate, AwardCategoryCode, IsCurrent, [Role], RoleCode,
        PhotoImageId, IsActive
    )
    SELECT source.Id, source.PlayId, @Now, @AdminId, NULL, NULL, 1,
           source.Candidate, source.AwardCategoryCode, source.IsCurrent,
           source.[Role], source.RoleCode, NULL, 1
    FROM @Candidates source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories target WHERE target.Id = source.Id
    );

    INSERT INTO dbo.JuryAssignedPlays
        (Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, JuryId)
    SELECT NEWID(), play.Id, @Now, @AdminId, NULL, NULL, 1, jury.Id
    FROM @Plays play
    CROSS JOIN @Juries jury
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryAssignedPlays existing
        WHERE existing.PlayId = play.Id AND existing.JuryId = jury.Id
          AND existing.IsPublished = 1
    );

    INSERT INTO dbo.JuryGameTicketFees
        (Id, UserId, PlayId, TicketFee, CreatedAt, CreatedBy,
         UpdatedAt, UpdatedBy, IsPublished)
    SELECT NEWID(), jury.Id, play.Id,
           CONVERT(decimal(10,2), 120 + (ABS(CHECKSUM(jury.Id, play.Id)) % 9) * 25),
           @Now, @AdminId, NULL, NULL, 1
    FROM @Juries jury
    CROSS JOIN @Plays play
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryGameTicketFees existing
        WHERE existing.UserId = jury.Id AND existing.PlayId = play.Id
          AND existing.IsPublished = 1
    );

    INSERT INTO dbo.JuryVotes
        (Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
         IsPublished, Score, JuryId, IsActive)
    SELECT NEWID(), candidate.Id, DATEADD(MINUTE, juryOrder.RowNumber, @Now),
           @AdminId, NULL, NULL, 1,
           1 + (ABS(CHECKSUM(candidate.Id, jury.Id)) % 10), jury.Id, 1
    FROM
    (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY Id) AS RowNumber FROM @Juries
    ) juryOrder
    INNER JOIN @Juries jury ON jury.Id = juryOrder.Id
    CROSS JOIN
    (
        SELECT candidate.Id
        FROM dbo.PlayAwardCategories candidate
        INNER JOIN @Plays play ON play.Id = candidate.PlayId
        WHERE play.RecordType = 0
          AND candidate.IsPublished = 1
          AND candidate.IsActive = 1
          AND candidate.IsCurrent = 1
    ) candidate
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes existing
        WHERE existing.PlayAwardCategoryId = candidate.Id
          AND existing.JuryId = jury.Id
          AND existing.IsPublished = 1
    );

    INSERT INTO dbo.Blacklist (Id, JuryId, PlayId, CreatedBy, CreatedOn, IsPublished)
    SELECT 'A0000000-0000-0000-0000-000000000001',
           '51000000-0000-0000-0000-000000000012',
           '70000000-0000-0000-0000-000000000006', @AdminId, @Now, 1
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Blacklist
        WHERE JuryId = '51000000-0000-0000-0000-000000000012'
          AND PlayId = '70000000-0000-0000-0000-000000000006'
          AND IsPublished = 1
    );

    DECLARE @Forms TABLE
    (
        Id uniqueidentifier NOT NULL,
        ApplicationNumber nvarchar(6) NOT NULL,
        RepertoireName nvarchar(500) NOT NULL,
        TheatreName nvarchar(500) NOT NULL,
        ApplicantName nvarchar(100) NOT NULL,
        Email nvarchar(150) NOT NULL
    );

    INSERT INTO @Forms VALUES
    ('F0000000-0000-0000-0000-000000000001', N'SD0001', N'Kum Saati', N'Mavi Sahne', N'Ayşe Güler', N'ayse.guler@afife.test'),
    ('F0000000-0000-0000-0000-000000000002', N'SD0002', N'Yolculuk', N'Yeni Tiyatro', N'Bora Keskin', N'bora.keskin@afife.test'),
    ('F0000000-0000-0000-0000-000000000003', N'SD0003', N'Kuşlar', N'Özgür Sahne', N'Cansu Bilge', N'cansu.bilge@afife.test'),
    ('F0000000-0000-0000-0000-000000000004', N'SD0004', N'Masallar', N'Kent Oyuncuları', N'Doruk Tuna', N'doruk.tuna@afife.test'),
    ('F0000000-0000-0000-0000-000000000005', N'SD0005', N'Kıyı', N'Sahil Tiyatrosu', N'Esra Deniz', N'esra.deniz@afife.test');

    INSERT INTO dbo.Form
    (
        ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
        TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
        Phone, Email, Director, ContactName, ContactPhone, LeadActress,
        LeadActor, SupportActress, SupportActor, StageDesign, ClothesDesign,
        LightDesign, StageMusic, Choreography, IsPublished, Id, LegacyId,
        SeasonId, IsActive
    )
    SELECT source.ApplicationNumber, CONVERT(datetime, '2026-03-15T10:00:00'), NULL,
           source.RepertoireName, source.TheatreName, CONVERT(date, '2026-04-10'),
           N'[{"Location":"İstanbul","Date":"10/04/2026","Time":"20:30"}]',
           source.ApplicantName, N'Yetkili', N'5553000000', source.Email,
           N'Test Yönetmen', source.ApplicantName, N'5553000001',
           N'[{"Name":"Test Kadın Oyuncu"}]', N'[{"Name":"Test Erkek Oyuncu"}]',
           N'[{"Name":"Test Yardımcı Kadın"}]', N'[{"Name":"Test Yardımcı Erkek"}]',
           N'[{"Name":"Test Sahne Tasarımcısı"}]', N'[{"Name":"Test Giysi Tasarımcısı"}]',
           N'[{"Name":"Test Işık Tasarımcısı"}]', N'[{"Name":"Test Müzisyen"}]',
           N'[{"Name":"Test Koreograf"}]', 1, source.Id, NULL, NULL, 1
    FROM @Forms source
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form target
        WHERE target.Id = source.Id
           OR (target.ApplicationNumber = source.ApplicationNumber AND target.IsPublished = 1)
    );

    IF OBJECT_ID(N'dbo.usp_RefreshSeasonStatistics', N'P') IS NOT NULL
        EXEC dbo.usp_RefreshSeasonStatistics;
    IF OBJECT_ID(N'dbo.usp_RefreshRankings', N'P') IS NOT NULL
        EXEC dbo.usp_RefreshRankings;

    COMMIT TRANSACTION;

    SELECT N'Users' AS TableName, COUNT_BIG(*) AS PublishedTestRows
    FROM dbo.Users WHERE IsPublished = 1 AND (Id = @AdminId OR Username LIKE N'juri%')
    UNION ALL
    SELECT N'Announcements', COUNT_BIG(*) FROM dbo.Announcements
    WHERE IsPublished = 1 AND Id IN
        ('B0000000-0000-0000-0000-000000000001', 'B0000000-0000-0000-0000-000000000002')
    UNION ALL
    SELECT N'Plays', COUNT_BIG(*) FROM dbo.Plays
    WHERE IsPublished = 1 AND (Id IN (SELECT Id FROM @Plays) OR SourceFormId IN (SELECT Id FROM @Forms))
    UNION ALL
    SELECT N'PlayAwardCategories', COUNT_BIG(*) FROM dbo.PlayAwardCategories
    WHERE IsPublished = 1 AND PlayId IN
        (SELECT Id FROM dbo.Plays WHERE Id IN (SELECT Id FROM @Plays) OR SourceFormId IN (SELECT Id FROM @Forms))
    UNION ALL
    SELECT N'JuryVotes', COUNT_BIG(*) FROM dbo.JuryVotes
    WHERE IsPublished = 1 AND JuryId IN (SELECT Id FROM @Juries)
    UNION ALL
    SELECT N'JuryGameTicketFees', COUNT_BIG(*) FROM dbo.JuryGameTicketFees
    WHERE IsPublished = 1 AND UserId IN (SELECT Id FROM @Juries)
    UNION ALL
    SELECT N'JuryAssignedPlays', COUNT_BIG(*) FROM dbo.JuryAssignedPlays
    WHERE IsPublished = 1 AND JuryId IN (SELECT Id FROM @Juries)
    UNION ALL
    SELECT N'Form', COUNT_BIG(*) FROM dbo.Form
    WHERE IsPublished = 1 AND Id IN (SELECT Id FROM @Forms);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
