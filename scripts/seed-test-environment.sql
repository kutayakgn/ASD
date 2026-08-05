/*
    YkbAfife test-environment seed

    Creates:
      - 20 jury users (RoleCode = 2; no admin users)
      - 15 plays (12 Kunye, 3 AfifeAdmin)
      - candidates, historical replacements, votes, assignments, ticket fees,
        and blacklist rows

    Safety:
      - Refuses to run on a database whose name does not contain "Test".
      - Never deletes or updates pre-existing business rows.
      - Does not write Announcements, AwardCategories, Images, Manager,
        PlayStatuses, or Roles.
      - Uses stable IDs and logical existence checks, so reruns are idempotent.
      - Trigger-managed Rankings and season counters are expected to recalculate.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() NOT LIKE N'%Test%'
    THROW 53000, N'Bu seed yalnızca adında Test geçen bir veritabanında çalıştırılabilir.', 1;

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryAssignedPlays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryGameTicketFees', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Blacklist', N'U') IS NULL
    THROW 53001, N'Gerekli uygulama tablolarından en az biri bulunamadı. Önce migrationları çalıştırın.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 2 AND IsPublished = 1)
    THROW 53002, N'RoleCode 2 olan yayımlanmış Jüri rolü bulunamadı.', 1;

IF EXISTS
(
    SELECT required.Code
    FROM (VALUES (1), (2), (3), (4), (5), (6)) AS required(Code)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayStatuses AS status
        WHERE status.StatusCode = required.Code AND status.IsPublished = 1
    )
)
    THROW 53003, N'Gerekli PlayStatuses kodlarından biri bulunamadı.', 1;

IF EXISTS
(
    SELECT required.Code
    FROM (VALUES (1001), (1002), (1003), (1004)) AS required(Code)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.AwardCategories AS category
        WHERE category.CategoryCode = required.Code AND category.IsPublished = 1
    )
)
    THROW 53004, N'Gerekli AwardCategories kodlarından biri bulunamadı.', 1;

DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
DECLARE @CorrelationId uniqueidentifier = NEWID();
DECLARE @PasswordHash nvarchar(500) = N'oDajqYzI1FXAP9N3WLa2B4PNn0pYLTdgy52ZUCsOQ7k/EiYF';

EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=@CorrelationId;
EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=N'test-environment-seed';
EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=N'Test verisi oluşturma';
EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=N'AfifeAdmin-TestSeed';
EXEC sys.sp_set_session_context @key=N'AdminRequestPath', @value=N'scripts/seed-test-environment.sql';

DECLARE @Juries TABLE
(
    JuryNo int NOT NULL PRIMARY KEY,
    Id uniqueidentifier NOT NULL UNIQUE,
    FirstName nvarchar(100) NOT NULL,
    LastName nvarchar(100) NOT NULL,
    Username nvarchar(100) NOT NULL,
    Email nvarchar(255) NOT NULL,
    Phone nvarchar(30) NULL,
    IsActive bit NOT NULL,
    IsPublished bit NOT NULL
);

INSERT INTO @Juries
    (JuryNo, Id, FirstName, LastName, Username, Email, Phone, IsActive, IsPublished)
VALUES
    (1,  'E1000000-0000-0000-0000-000000000001', N'Ahmet',   N'Yılmaz',     N'test.juri01', N'test.juri01@afife.test', N'5551000001', 1, 1),
    (2,  'E1000000-0000-0000-0000-000000000002', N'Aylin',   N'Kaya',       N'test.juri02', N'test.juri02@afife.test', N'5551000002', 1, 1),
    (3,  'E1000000-0000-0000-0000-000000000003', N'Berk',    N'Demir',      N'test.juri03', N'test.juri03@afife.test', N'5551000003', 1, 1),
    (4,  'E1000000-0000-0000-0000-000000000004', N'Ceren',   N'Aksoy',      N'test.juri04', N'test.juri04@afife.test', N'5551000004', 1, 1),
    (5,  'E1000000-0000-0000-0000-000000000005', N'Deniz',   N'Şahin',      N'test.juri05', N'test.juri05@afife.test', N'5551000005', 1, 1),
    (6,  'E1000000-0000-0000-0000-000000000006', N'Ece',     N'Çelik',      N'test.juri06', N'test.juri06@afife.test', N'5551000006', 1, 1),
    (7,  'E1000000-0000-0000-0000-000000000007', N'Emre',    N'Aydın',      N'test.juri07', N'test.juri07@afife.test', N'5551000007', 1, 1),
    (8,  'E1000000-0000-0000-0000-000000000008', N'Esra',    N'Koç',        N'test.juri08', N'test.juri08@afife.test', N'5551000008', 1, 1),
    (9,  'E1000000-0000-0000-0000-000000000009', N'Gökhan',  N'Arslan',     N'test.juri09', N'test.juri09@afife.test', N'5551000009', 1, 1),
    (10, 'E1000000-0000-0000-0000-000000000010', N'İpek',    N'Öztürk',     N'test.juri10', N'test.juri10@afife.test', N'5551000010', 1, 1),
    (11, 'E1000000-0000-0000-0000-000000000011', N'Kerem',   N'Polat',      N'test.juri11', N'test.juri11@afife.test', N'5551000011', 1, 1),
    (12, 'E1000000-0000-0000-0000-000000000012', N'Leyla',   N'Kurt',       N'test.juri12', N'test.juri12@afife.test', N'5551000012', 1, 1),
    (13, 'E1000000-0000-0000-0000-000000000013', N'Mert',    N'Güneş',      N'test.juri13', N'test.juri13@afife.test', N'5551000013', 1, 1),
    (14, 'E1000000-0000-0000-0000-000000000014', N'Nazlı',   N'Yıldız',     N'test.juri14', N'test.juri14@afife.test', N'5551000014', 1, 1),
    (15, 'E1000000-0000-0000-0000-000000000015', N'Onur',    N'Erdoğan',    N'test.juri15', N'test.juri15@afife.test', N'5551000015', 1, 1),
    (16, 'E1000000-0000-0000-0000-000000000016', N'Pelin',   N'Özdemir',    N'test.juri16', N'test.juri16@afife.test', N'5551000016', 1, 1),
    (17, 'E1000000-0000-0000-0000-000000000017', N'Rıza',    N'Keskin',     N'test.juri17', N'test.juri17@afife.test', N'5551000017', 0, 1),
    (18, 'E1000000-0000-0000-0000-000000000018', N'Selin',   N'Tunç',       N'test.juri18', N'test.juri18@afife.test', N'5551000018', 0, 1),
    (19, 'E1000000-0000-0000-0000-000000000019', N'Tolga',   N'Bulut',      N'test.juri19', N'test.juri19@afife.test', N'5551000019', 0, 0),
    (20, 'E1000000-0000-0000-0000-000000000020', N'Zeynep',  N'Kara',       N'test.juri20', N'test.juri20@afife.test', N'5551000020', 0, 0);

DECLARE @Plays TABLE
(
    PlayNo int NOT NULL PRIMARY KEY,
    Id uniqueidentifier NOT NULL UNIQUE,
    PlayName nvarchar(255) NOT NULL,
    TheaterName nvarchar(255) NOT NULL,
    Slug varchar(255) NOT NULL,
    StatusCode int NOT NULL,
    CreatedAt datetime2(7) NOT NULL,
    RecordType bit NOT NULL,
    JuriOylamaStatus bit NOT NULL,
    KunyeGirisStatus bit NOT NULL,
    IsActive bit NOT NULL,
    IsPublished bit NOT NULL
);

INSERT INTO @Plays
    (PlayNo, Id, PlayName, TheaterName, Slug, StatusCode, CreatedAt, RecordType,
     JuriOylamaStatus, KunyeGirisStatus, IsActive, IsPublished)
VALUES
    (1,  'E2000000-0000-0000-0000-000000000001', N'Kayıp Zamanın İzinde', N'Atlas Sahne',       'test-kayip-zamanin-izinde', 1, '2025-09-05T19:30:00', 0, 1, 1, 1, 1),
    (2,  'E2000000-0000-0000-0000-000000000002', N'Bir Yaz Gecesi',       N'Mavi Tiyatro',      'test-bir-yaz-gecesi',       1, '2025-09-18T20:00:00', 0, 1, 0, 1, 1),
    (3,  'E2000000-0000-0000-0000-000000000003', N'Sessiz Şehir',         N'Kuzey Sanat',       'test-sessiz-sehir',         2, '2025-10-02T20:30:00', 0, 0, 1, 1, 1),
    (4,  'E2000000-0000-0000-0000-000000000004', N'Rüzgarın Sesi',        N'Perde Tiyatrosu',   'test-ruzgarin-sesi',        3, '2025-10-17T19:00:00', 0, 0, 1, 1, 1),
    (5,  'E2000000-0000-0000-0000-000000000005', N'Gölgedeki İnsan',      N'Yeni Sahne',        'test-golgedeki-insan',      4, '2025-11-04T20:00:00', 0, 0, 0, 1, 1),
    (6,  'E2000000-0000-0000-0000-000000000006', N'Kırık Saatler',        N'Düş Atölyesi',      'test-kirik-saatler',        5, '2025-11-21T20:30:00', 0, 0, 0, 1, 1),
    (7,  'E2000000-0000-0000-0000-000000000007', N'Son Mektup',           N'Kent Oyuncuları',   'test-son-mektup',           6, '2025-12-06T19:30:00', 0, 0, 0, 0, 1),
    (8,  'E2000000-0000-0000-0000-000000000008', N'Yalnız Ada',           N'İstanbul Sahnesi',  'test-yalniz-ada',           1, '2025-12-19T20:00:00', 0, 1, 1, 0, 1),
    (9,  'E2000000-0000-0000-0000-000000000009', N'Beyaz Gece',           N'Anadolu Tiyatrosu', 'test-beyaz-gece',           1, '2026-01-09T20:30:00', 0, 1, 1, 1, 1),
    (10, 'E2000000-0000-0000-0000-000000000010', N'Çember',               N'Kare Sanat',        'test-cember',               2, '2026-02-03T20:00:00', 0, 0, 1, 1, 1),
    (11, 'E2000000-0000-0000-0000-000000000011', N'Duvarların Ardında',   N'Sahne 34',          'test-duvarlarin-ardinda',   1, '2026-03-12T19:30:00', 0, 1, 1, 1, 1),
    (12, 'E2000000-0000-0000-0000-000000000012', N'Yağmurdan Sonra',      N'Güney Tiyatro',     'test-yagmurdan-sonra',      1, '2026-04-08T20:00:00', 0, 1, 1, 1, 1),
    (13, 'E2000000-0000-0000-0000-000000000013', N'Jüri İzleme Oyunu',    N'Deneme Sahnesi',    'test-juri-izleme-oyunu',    2, '2026-04-21T20:00:00', 1, 0, 0, 1, 1),
    (14, 'E2000000-0000-0000-0000-000000000014', N'Bilet Kontrol Oyunu',  N'Kontrol Tiyatrosu', 'test-bilet-kontrol-oyunu',  6, '2026-05-02T20:00:00', 1, 0, 0, 1, 1),
    (15, 'E2000000-0000-0000-0000-000000000015', N'Silinmiş Admin Oyunu', N'Arşiv Sahnesi',     'test-silinmis-admin-oyunu', 3, '2026-05-10T20:00:00', 1, 0, 0, 0, 0);

IF EXISTS
(
    SELECT 1
    FROM @Juries AS seed
    INNER JOIN dbo.Users AS existing
        ON (existing.Username = seed.Username OR existing.Email = seed.Email)
       AND existing.RoleCode = 2
       AND existing.IsPublished = 1
       AND existing.Id <> seed.Id
)
    THROW 53005, N'Test jüri kullanıcı adı veya e-postası başka bir yayımlanmış kayıtta kullanılıyor.', 1;

IF EXISTS
(
    SELECT 1 FROM @Juries AS seed
    INNER JOIN dbo.Users AS existing ON existing.Id = seed.Id
    WHERE existing.RoleCode <> 2
)
    THROW 53006, N'Test jüri GUID değerlerinden biri jüri olmayan mevcut bir kullanıcıya ait.', 1;

IF EXISTS
(
    SELECT 1 FROM @Plays AS seed
    INNER JOIN dbo.Plays AS existing ON existing.Id = seed.Id
    WHERE existing.RecordType <> seed.RecordType
)
    THROW 53007, N'Test oyun GUID değerlerinden biri farklı RecordType değerli mevcut bir oyuna ait.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Users
    (
        Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
        CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        RoleCode, GroupCode, PhotoImageId, IsActive
    )
    SELECT
        seed.Id, seed.FirstName, seed.LastName, seed.Phone, seed.Username,
        @PasswordHash, seed.Email, DATEADD(MINUTE, seed.JuryNo, '2025-09-01T09:00:00'),
        NULL, NULL, NULL, seed.IsPublished, 2, NULL, NULL, seed.IsActive
    FROM @Juries AS seed
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Users AS existing WHERE existing.Id = seed.Id);

    INSERT INTO dbo.Plays
    (
        Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, Slug, TheaterName, Phone, ContactPersonName,
        ContactPersonPhone, Address, Email, JuriOylamaStatus,
        KunyeGirisStatus, RecordType, SourceFormId, IsActive
    )
    SELECT
        seed.Id, seed.PlayName, seed.StatusCode, seed.CreatedAt, NULL, NULL, NULL,
        seed.IsPublished, seed.Slug, seed.TheaterName, N'02125550' + RIGHT('00' + CONVERT(varchar(2), seed.PlayNo), 2),
        N'Test İletişim ' + CONVERT(nvarchar(2), seed.PlayNo),
        N'555200' + RIGHT('0000' + CONVERT(varchar(4), seed.PlayNo), 4),
        N'Test Mahallesi, İstanbul',
        N'oyun' + CONVERT(nvarchar(2), seed.PlayNo) + N'@afife.test',
        seed.JuriOylamaStatus, seed.KunyeGirisStatus, seed.RecordType, NULL, seed.IsActive
    FROM @Plays AS seed
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Plays AS existing WHERE existing.Id = seed.Id);

    DECLARE @Candidates TABLE
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        PlayNo int NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        RoleName nvarchar(200) NULL,
        RoleCode int NOT NULL,
        IsCurrent bit NOT NULL,
        IsActive bit NOT NULL,
        IsPublished bit NOT NULL
    );

    INSERT INTO @Candidates
        (Id, PlayNo, AwardCategoryCode, Candidate, RoleName, RoleCode, IsCurrent, IsActive, IsPublished)
    VALUES
        ('E3100000-0000-0000-0000-000000000001', 1,  1002, N'Sedef Akın',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000002', 2,  1002, N'Barış Koral',      NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000003', 3,  1002, N'Derya Işık',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000004', 4,  1002, N'Caner Uslu',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000005', 5,  1002, N'Elif Sönmez',      NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000006', 6,  1002, N'Gökçe Er',         NULL, 0, 1, 0, 1),
        ('E3100000-0000-0000-0000-000000000007', 7,  1002, N'Hakan Tekin',      NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000008', 8,  1002, N'İlke Başar',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000009', 9,  1002, N'Jale Güven',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000010', 10, 1002, N'Koray Eren',       NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000011', 11, 1002, N'Lale Arı',         NULL, 0, 1, 1, 1),
        ('E3100000-0000-0000-0000-000000000012', 12, 1002, N'Metin Ay',         NULL, 0, 1, 1, 1),

        ('E3200000-0000-0000-0000-000000000001', 1,  1003, N'Aslı Deniz',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000002', 2,  1003, N'Banu Sezer',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000003', 3,  1003, N'Cansu Ateş',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000004', 4,  1003, N'Damla Ekin',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000005', 5,  1003, N'Eylül Su',         N'Başrol', 1, 1, 0, 0),
        ('E3200000-0000-0000-0000-000000000006', 6,  1003, N'Feride Al',        N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000007', 7,  1003, N'Gizem Ada',        N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000008', 8,  1003, N'Hülya Öz',         N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000009', 9,  1003, N'Irmak Gül',        N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000010', 10, 1003, N'Jülide Ece',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000011', 11, 1003, N'Kumsal Tan',       N'Başrol', 1, 1, 1, 1),
        ('E3200000-0000-0000-0000-000000000012', 12, 1003, N'Leman Soy',        N'Başrol', 1, 1, 1, 1),

        ('E3300000-0000-0000-0000-000000000001', 1,  1004, N'Kadir Taylan',     N'Gezgin', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000002', 2,  1004, N'Levent Çınar',     N'Kaptan', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000003', 3,  1004, N'Murat Ersoy',      N'Öğretmen', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000004', 4,  1004, N'Necip Uçar',       N'Baba', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000005', 5,  1004, N'Ozan Yüce',        N'Doktor', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000006', 6,  1004, N'Poyraz Can',       N'Yolcu', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000007', 7,  1004, N'Rauf Efe',         N'Komutan', 2, 1, 1, 1),
        ('E3300000-0000-0000-0000-000000000008', 8,  1004, N'Sarp Tuna',        N'Yazar', 2, 1, 1, 1),

        ('E3400000-0000-0000-0000-000000000001', 1,  1004, N'Ahmet Mümtaz',    N'Gezgin', 2, 0, 1, 1),
        ('E3400000-0000-0000-0000-000000000002', 2,  1003, N'Ayşe Olgun',      N'Başrol', 1, 0, 1, 1),
        ('E3400000-0000-0000-0000-000000000003', 3,  1003, N'Belgin Öz',       N'Başrol', 1, 0, 0, 1);

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId, IsActive
    )
    SELECT
        candidate.Id, play.Id, DATEADD(DAY, 2, play.CreatedAt), NULL, NULL, NULL,
        candidate.IsPublished, candidate.Candidate, candidate.AwardCategoryCode,
        candidate.IsCurrent, candidate.RoleName, candidate.RoleCode, NULL, candidate.IsActive
    FROM @Candidates AS candidate
    INNER JOIN @Plays AS play ON play.PlayNo = candidate.PlayNo
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories AS existing WHERE existing.Id = candidate.Id
    );

    /* Published assignments include active and inactive juries; jury 19/20 are soft-deleted and excluded. */
    INSERT INTO dbo.JuryAssignedPlays
        (Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, JuryId)
    SELECT
        NEWID(), play.Id, DATEADD(DAY, jury.JuryNo % 8, play.CreatedAt), NULL, NULL, NULL,
        CASE WHEN play.PlayNo = 15 THEN 0 ELSE 1 END, jury.Id
    FROM @Juries AS jury
    CROSS JOIN @Plays AS play
    WHERE jury.JuryNo <= 18
      AND (jury.JuryNo + play.PlayNo) % 3 <> 0
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.JuryAssignedPlays AS existing
          WHERE existing.PlayId = play.Id AND existing.JuryId = jury.Id
      );

    INSERT INTO dbo.JuryGameTicketFees
        (Id, UserId, PlayId, TicketFee, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished)
    SELECT
        NEWID(), jury.Id, play.Id,
        CONVERT(decimal(10,2), 150 + (play.PlayNo * 17) + (jury.JuryNo % 5) * 12.50),
        DATEADD(DAY, jury.JuryNo % 10, play.CreatedAt), NULL, NULL, NULL,
        CASE WHEN play.PlayNo = 15 OR (jury.JuryNo = 18 AND play.PlayNo % 4 = 0) THEN 0 ELSE 1 END
    FROM @Juries AS jury
    CROSS JOIN @Plays AS play
    WHERE jury.JuryNo <= 18
      AND (jury.JuryNo + play.PlayNo) % 2 = 0
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.JuryGameTicketFees AS existing
          WHERE existing.PlayId = play.Id AND existing.UserId = jury.Id
      );

    DECLARE @VoteTargets TABLE
    (
        PlayNo int NOT NULL,
        PlayAwardCategoryId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        MinJuryNo int NOT NULL,
        MaxJuryNo int NOT NULL,
        PRIMARY KEY (PlayAwardCategoryId)
    );

    /* Category 1001 vote counts vary from 0 to 18 to exercise both watch-count tabs. */
    INSERT INTO @VoteTargets
        (PlayNo, PlayAwardCategoryId, AwardCategoryCode, MinJuryNo, MaxJuryNo)
    SELECT
        play.PlayNo, candidate.Id, 1001, 1,
        CASE play.PlayNo
            WHEN 1 THEN 18 WHEN 2 THEN 12 WHEN 3 THEN 8 WHEN 4 THEN 4
            WHEN 5 THEN 3 WHEN 6 THEN 0 WHEN 7 THEN 6 WHEN 8 THEN 5
            WHEN 9 THEN 15 WHEN 10 THEN 2 WHEN 11 THEN 10 ELSE 6 END
    FROM @Plays AS play
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.PlayId = play.Id
       AND candidate.AwardCategoryCode = 1001
       AND candidate.RoleCode = 0
    WHERE play.RecordType = 0;

    INSERT INTO @VoteTargets
        (PlayNo, PlayAwardCategoryId, AwardCategoryCode, MinJuryNo, MaxJuryNo)
    SELECT
        candidate.PlayNo, candidate.Id, candidate.AwardCategoryCode,
        CASE
            WHEN candidate.Id = 'E3300000-0000-0000-0000-000000000001' THEN 6
            WHEN candidate.Id = 'E3200000-0000-0000-0000-000000000002' THEN 5
            ELSE 1
        END,
        CASE
            WHEN candidate.Id = 'E3400000-0000-0000-0000-000000000001' THEN 5
            WHEN candidate.Id = 'E3300000-0000-0000-0000-000000000001' THEN 15
            WHEN candidate.Id = 'E3400000-0000-0000-0000-000000000002' THEN 4
            WHEN candidate.Id = 'E3200000-0000-0000-0000-000000000002' THEN 14
            WHEN candidate.AwardCategoryCode = 1002 THEN 4 + (candidate.PlayNo % 10)
            WHEN candidate.AwardCategoryCode = 1003 THEN 3 + (candidate.PlayNo % 12)
            ELSE 5 + (candidate.PlayNo % 10)
        END
    FROM @Candidates AS candidate
    WHERE candidate.IsPublished = 1;

    INSERT INTO dbo.JuryVotes
    (
        Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, Score, JuryId, IsActive
    )
    SELECT
        NEWID(), target.PlayAwardCategoryId,
        DATEADD(MINUTE, jury.JuryNo * 7, DATEADD(DAY, 14, play.CreatedAt)),
        NULL, NULL, NULL,
        CASE
            WHEN jury.JuryNo = target.MaxJuryNo AND target.PlayNo IN (4, 8, 12) THEN 0
            ELSE 1
        END,
        ((jury.JuryNo * 3 + target.PlayNo * 2 + target.AwardCategoryCode) % 10) + 1,
        jury.Id,
        CASE
            WHEN jury.JuryNo = target.MaxJuryNo AND target.PlayNo IN (4, 8, 12) THEN 0
            WHEN jury.JuryNo = target.MaxJuryNo - 1 AND target.PlayNo IN (3, 6, 9) THEN 0
            WHEN candidate.IsActive = 0 OR candidate.IsPublished = 0 THEN 0
            ELSE 1
        END
    FROM @VoteTargets AS target
    INNER JOIN @Plays AS play ON play.PlayNo = target.PlayNo
    INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = target.PlayAwardCategoryId
    INNER JOIN @Juries AS jury
        ON jury.JuryNo BETWEEN target.MinJuryNo AND target.MaxJuryNo
       AND jury.IsPublished = 1
    WHERE target.MaxJuryNo >= target.MinJuryNo
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.JuryVotes AS existing
          WHERE existing.PlayAwardCategoryId = target.PlayAwardCategoryId
            AND existing.JuryId = jury.Id
      );

    /*
       Jury 1 first voted for the old Gezgin candidate. This later current-candidate
       vote exercises the logical-role trigger: the old vote is retained but becomes
       IsPublished=0 and IsActive=0.
    */
    INSERT INTO dbo.JuryVotes
    (
        Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, Score, JuryId, IsActive
    )
    SELECT
        NEWID(), 'E3300000-0000-0000-0000-000000000001',
        DATEADD(DAY, 30, play.CreatedAt), NULL, NULL, NULL, 1, 9, jury.Id, 1
    FROM @Juries AS jury
    INNER JOIN @Plays AS play ON play.PlayNo = 1
    WHERE jury.JuryNo = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.JuryVotes AS existing
          WHERE existing.PlayAwardCategoryId = 'E3300000-0000-0000-0000-000000000001'
            AND existing.JuryId = jury.Id
      );

    INSERT INTO dbo.Blacklist
        (Id, JuryId, PlayId, CreatedBy, CreatedOn, IsPublished)
    SELECT
        NEWID(), jury.Id, play.Id,
        (SELECT Id FROM @Juries WHERE JuryNo = 1),
        CONVERT(datetime2(0), DATEADD(DAY, 20, play.CreatedAt)),
        CASE WHEN play.PlayNo = 4 THEN 0 ELSE 1 END
    FROM @Juries AS jury
    INNER JOIN @Plays AS play ON play.PlayNo = jury.JuryNo
    WHERE jury.JuryNo BETWEEN 1 AND 4
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.Blacklist AS existing
          WHERE existing.JuryId = jury.Id AND existing.PlayId = play.Id
      );

    COMMIT TRANSACTION;

    /* Result sets below make the generated states and calculations immediately inspectable. */
    SELECT
        N'Users' AS Entity,
        COUNT(*) AS TestRowCount,
        SUM(CASE WHEN IsPublished = 1 AND IsActive = 1 THEN 1 ELSE 0 END) AS PublishedActive,
        SUM(CASE WHEN IsPublished = 1 AND IsActive = 0 THEN 1 ELSE 0 END) AS PublishedInactive,
        SUM(CASE WHEN IsPublished = 0 THEN 1 ELSE 0 END) AS SoftDeleted
    FROM dbo.Users WHERE Id IN (SELECT Id FROM @Juries)
    UNION ALL
    SELECT
        N'Plays', COUNT(*),
        SUM(CASE WHEN IsPublished = 1 AND IsActive = 1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN IsPublished = 1 AND IsActive = 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN IsPublished = 0 THEN 1 ELSE 0 END)
    FROM dbo.Plays WHERE Id IN (SELECT Id FROM @Plays);

    SELECT
        play.PlayName,
        CASE play.RecordType WHEN 0 THEN N'Künye Giriş' ELSE N'Admin Giriş' END AS RecordType,
        play.StatusCode, play.JuriOylamaStatus, play.KunyeGirisStatus,
        play.IsActive, play.IsPublished,
        COUNT(DISTINCT watched.JuryId) AS UniqueWatchCount
    FROM dbo.Plays AS play
    OUTER APPLY
    (
        SELECT vote.JuryId
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        WHERE candidate.PlayId = play.Id
          AND vote.IsPublished = 1
        UNION
        SELECT fee.UserId
        FROM dbo.JuryGameTicketFees AS fee
        WHERE fee.PlayId = play.Id AND fee.IsPublished = 1
    ) AS watched
    WHERE play.Id IN (SELECT Id FROM @Plays)
    GROUP BY play.PlayName, play.RecordType, play.StatusCode,
             play.JuriOylamaStatus, play.KunyeGirisStatus,
             play.IsActive, play.IsPublished
    ORDER BY play.RecordType, play.PlayName;

    SELECT
        play.PlayName,
        category.CategoryName,
        candidate.Candidate,
        candidate.Role,
        candidate.IsCurrent,
        candidate.IsActive AS CandidateIsActive,
        candidate.IsPublished AS CandidateIsPublished,
        ranking.NumberOfActiveVote,
        ranking.ArithmeticMean,
        ranking.TrimmedMean,
        ranking.ArithmeticVariance,
        ranking.ConfidenceValue,
        ranking.ArithmeticRank,
        ranking.TrimmedRank,
        ranking.IsPublished AS RankingIsPublished
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.AwardCategories AS category
        ON category.CategoryCode = candidate.AwardCategoryCode
    LEFT JOIN dbo.Rankings AS ranking
        ON ranking.PlayAwardCategoryId = candidate.Id
    WHERE play.Id IN (SELECT Id FROM @Plays)
    ORDER BY category.CategoryCode, play.PlayName, candidate.RoleCode,
             candidate.IsCurrent DESC, candidate.Candidate;

    SELECT
        play.PlayName,
        category.CategoryName,
        candidate.Role,
        candidate.Candidate,
        jury.FirstName + N' ' + jury.LastName AS Jury,
        vote.Score,
        vote.IsActive,
        vote.IsPublished,
        vote.CreatedAt
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.AwardCategories AS category
        ON category.CategoryCode = candidate.AwardCategoryCode
    INNER JOIN dbo.Users AS jury ON jury.Id = vote.JuryId
    WHERE play.Id = 'E2000000-0000-0000-0000-000000000001'
      AND candidate.AwardCategoryCode = 1004
      AND jury.Id = 'E1000000-0000-0000-0000-000000000001'
    ORDER BY vote.CreatedAt;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

    EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=NULL;
    EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=NULL;
    EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=NULL;
    EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=NULL;
    EXEC sys.sp_set_session_context @key=N'AdminRequestPath', @value=NULL;
    THROW;
END CATCH;

EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=NULL;
EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=NULL;
EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=NULL;
EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=NULL;
EXEC sys.sp_set_session_context @key=N'AdminRequestPath', @value=NULL;
