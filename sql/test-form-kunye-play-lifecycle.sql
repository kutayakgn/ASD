SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays', N'P') IS NULL
   OR OBJECT_ID(N'dbo.usp_ReassignFormSeasons', N'P') IS NULL
   OR COL_LENGTH(N'dbo.Form', N'IsActive') IS NULL
   OR COL_LENGTH(N'dbo.Plays', N'SourceFormId') IS NULL
   OR COL_LENGTH(N'dbo.Plays', N'IsActive') IS NULL
BEGIN
    THROW 52500, N'Önce migrate-forms-to-kunye-play-lifecycle.sql çalıştırılmalıdır.', 1;
END;
GO

/* Migration/backfill invariants on the persistent local data. */
IF EXISTS
(
    SELECT 1
    FROM dbo.Form AS formRecord
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND formRecord.CreatedDate IS NOT NULL
          AND CAST(formRecord.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(formRecord.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS expectedSeason
    WHERE formRecord.SeasonId <> expectedSeason.Id
       OR (formRecord.SeasonId IS NULL AND expectedSeason.Id IS NOT NULL)
       OR (formRecord.SeasonId IS NOT NULL AND expectedSeason.Id IS NULL)
)
    THROW 52501, N'FAIL: Form.SeasonId değerleri CreatedDate ve yayınlanmış sezonlarla uyumlu değil.', 1;
IF EXISTS
(
    SELECT 1
    FROM dbo.Form AS formRecord
    LEFT JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.Id IS NULL
)
    THROW 52502, N'FAIL: Aktif Form için Plays kaydı bulunamadı.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Plays AS play
    WHERE play.SourceFormId IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      )
)
    THROW 52503, N'FAIL: Form kaynaklı oyunda sistem kategorisi 1001 bulunamadı.', 1;

SELECT N'PASS' AS Result, N'Mevcut Form kayıtlarının SeasonId değerleri normalize; aktif kayıtların oyun ve kategori 1001 ilişkileri mevcut.' AS Scenario;
GO

DECLARE @Results TABLE
(
    ScenarioOrder int NOT NULL PRIMARY KEY,
    Result nvarchar(10) NOT NULL,
    Scenario nvarchar(500) NOT NULL
);

DECLARE @FormId uniqueidentifier = 'fa000000-0000-0000-0000-000000000001';
DECLARE @InactiveFormId uniqueidentifier = 'fa000000-0000-0000-0000-000000000002';
DECLARE @CandidateId uniqueidentifier = 'fa100000-0000-0000-0000-000000000001';
DECLARE @VoteId uniqueidentifier = 'fa200000-0000-0000-0000-000000000001';
DECLARE @TicketId uniqueidentifier = 'fa300000-0000-0000-0000-000000000001';
DECLARE @HistoricalTicketId uniqueidentifier = 'fa300000-0000-0000-0000-000000000002';
DECLARE @AssignmentId uniqueidentifier = 'fa400000-0000-0000-0000-000000000001';
DECLARE @BlacklistId uniqueidentifier = 'fa500000-0000-0000-0000-000000000001';
DECLARE @JuryId uniqueidentifier;
DECLARE @PlayId uniqueidentifier;
DECLARE @DefaultCandidateId uniqueidentifier;
DECLARE @SeasonId uniqueidentifier;
DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

SELECT TOP (1) @JuryId = Id
FROM dbo.Users
WHERE RoleCode = 2 AND IsPublished = 1 AND IsActive = 1
ORDER BY Id;

IF @JuryId IS NULL
    THROW 52504, N'Test için aktif jüri bulunamadı.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, UpdatedDate,
        RepertoireName, TheatreName, PremiereDate, Display,
        ApplicantName, ApplicantRole, Phone, Email, Director,
        ContactName, ContactPhone, LeadActress, LeadActor,
        SupportActress, SupportActor, StageDesign, ClothesDesign,
        LightDesign, StageMusic, Choreography, IsActive, IsPublished
    )
    VALUES
    (
        @FormId, N'FT9001', CONVERT(datetime2, '2026-03-15T12:00:00'), NULL,
        N'Form Yaşam Döngüsü Oyunu', N'Form Test Tiyatrosu',
        CONVERT(date, '2026-03-01'),
        N'[{"Location":"Test Sahnesi","Date":"15/03/2026","Time":"20:00"}]',
        N'Test Başvuran', N'Yapımcı', N'05550000001',
        N'form-test@afife.test', N'Test Yönetmen',
        N'Test İletişim', N'05550000002', NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL, 1, 1
    );

    SELECT @SeasonId = SeasonId FROM dbo.Form WHERE Id = @FormId;
    SELECT @PlayId = Id FROM dbo.Plays WHERE SourceFormId = @FormId;
    SELECT @DefaultCandidateId = Id
    FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1001 AND RoleCode = 0;

    IF @SeasonId IS NULL OR @PlayId IS NULL OR @DefaultCandidateId IS NULL
        THROW 52505, N'FAIL: Aktif Form create akışı sezon/oyun/kategori oluşturmadı.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId AND RecordType = 0 AND IsPublished = 1
          AND IsActive = 1 AND JuriOylamaStatus = 1 AND KunyeGirisStatus = 1
    )
        THROW 52506, N'FAIL: Yeni Künye oyununun başlangıç durumları hatalı.', 1;

    INSERT INTO @Results VALUES
        (1, N'PASS', N'Aktif Form insert: SeasonId otomatik, Play RecordType=0 ve kategori 1001 oluşturuldu.');

    UPDATE dbo.Form
    SET RepertoireName = N'Güncellenmiş Form Oyunu',
        TheatreName = N'Güncellenmiş Test Tiyatrosu',
        Phone = N'05559999991',
        ContactName = N'Yeni İletişim',
        ContactPhone = N'05559999992',
        Email = N'guncel-form@afife.test',
        UpdatedDate = @Now
    WHERE Id = @FormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId
          AND PlayName = N'Güncellenmiş Form Oyunu'
          AND TheaterName = N'Güncellenmiş Test Tiyatrosu'
          AND Phone = N'05559999991'
          AND ContactPersonName = N'Yeni İletişim'
          AND ContactPersonPhone = N'05559999992'
          AND Email = N'guncel-form@afife.test'
    )
        THROW 52507, N'FAIL: Form update alanları Plays tablosuna yansımadı.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE Id = @DefaultCandidateId
          AND Candidate = N'Güncellenmiş Test Tiyatrosu'
    )
        THROW 52508, N'FAIL: TheatreName kategori 1001 Candidate alanına yansımadı.', 1;

    INSERT INTO @Results VALUES
        (2, N'PASS', N'Form update: oyun alanları ve kategori 1001 tiyatro adayı senkronize edildi.');

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, PhotoImageId, CreatedAt, CreatedBy, UpdatedAt,
        UpdatedBy, IsPublished, IsActive, Candidate,
        AwardCategoryCode, IsCurrent, Role, RoleCode
    )
    VALUES
    (
        @CandidateId, @PlayId, NULL, @Now, NULL, NULL, NULL,
        1, 0, N'Bağımsız Pasif Yönetmen', 1002, 1, NULL, 0
    );

    INSERT INTO dbo.JuryVotes
    (
        Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt,
        UpdatedBy, IsPublished, IsActive, Score, JuryId
    )
    VALUES
    (
        @VoteId, @DefaultCandidateId, @Now, @JuryId, NULL,
        NULL, 1, 1, 8, @JuryId
    );

    INSERT INTO dbo.JuryGameTicketFees
        (Id, UserId, PlayId, TicketFee, CreatedAt, CreatedBy, IsPublished)
    VALUES
        (@TicketId, @JuryId, @PlayId, 250.00, @Now, @JuryId, 1),
        (@HistoricalTicketId, @JuryId, @PlayId, 100.00,
         DATEADD(DAY, -1, @Now), @JuryId, 0);

    INSERT INTO dbo.JuryAssignedPlays
        (Id, PlayId, CreatedAt, CreatedBy, IsPublished, JuryId)
    VALUES (@AssignmentId, @PlayId, @Now, @JuryId, 1, @JuryId);

    INSERT INTO dbo.Blacklist
        (Id, JuryId, PlayId, CreatedBy, CreatedOn, IsPublished)
    VALUES (@BlacklistId, @JuryId, @PlayId, @JuryId, @Now, 1);

    INSERT INTO @Results VALUES
        (3, N'PASS', N'Aday, jüri oyu, bilet ücreti, jüri ataması ve blacklist test kayıtları oluşturuldu.');

    UPDATE dbo.Form SET IsActive = 0, UpdatedDate = @Now WHERE Id = @FormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Form
        WHERE Id = @FormId AND IsPublished = 1 AND IsActive = 0
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 0
          AND JuriOylamaStatus = 0 AND KunyeGirisStatus = 0
    )
        THROW 52509, N'FAIL: Form veya Künye oyunu pasif duruma geçmedi.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE PlayId = @PlayId AND (IsPublished = 1 OR IsActive = 1)
    )
       OR EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE Id = @VoteId AND (IsPublished = 1 OR IsActive = 1)
    )
       OR EXISTS
    (
        SELECT 1 FROM dbo.JuryGameTicketFees
        WHERE Id = @TicketId AND IsPublished = 1
    )
       OR EXISTS
    (
        SELECT 1 FROM dbo.JuryAssignedPlays
        WHERE Id = @AssignmentId AND IsPublished = 1
    )
       OR EXISTS
    (
        SELECT 1 FROM dbo.Blacklist
        WHERE Id = @BlacklistId AND IsPublished = 1
    )
        THROW 52510, N'FAIL: Form bağımlılarından biri pasif/soft-delete olmadı.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.FormLifecycleStates
        WHERE FormId = @FormId AND IsPublished = 1
    )
        THROW 52511, N'FAIL: Form yaşam döngüsü snapshotı oluşmadı.', 1;

    INSERT INTO @Results VALUES
        (4, N'PASS', N'IsActive=0: oyun gizlendi, statüler kapandı ve tüm bağlı kayıtlar snapshot ile soft-delete/pasif oldu.');

    UPDATE dbo.Form SET IsActive = 1, UpdatedDate = @Now WHERE Id = @FormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 1
          AND JuriOylamaStatus = 1 AND KunyeGirisStatus = 1 AND StatusCode = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE Id = @DefaultCandidateId AND IsPublished = 1 AND IsActive = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE Id = @CandidateId AND IsPublished = 1 AND IsActive = 0
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE Id = @VoteId AND IsPublished = 1 AND IsActive = 1 AND Score = 8
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryGameTicketFees
        WHERE Id = @TicketId AND IsPublished = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryGameTicketFees
        WHERE Id = @HistoricalTicketId AND IsPublished = 0
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.JuryAssignedPlays
        WHERE Id = @AssignmentId AND IsPublished = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Blacklist
        WHERE Id = @BlacklistId AND IsPublished = 1
    )
       OR EXISTS
    (
        SELECT 1 FROM dbo.FormLifecycleStates
        WHERE FormId = @FormId AND IsPublished = 1
    )
        THROW 52512, N'FAIL: Form reaktivasyonu önceki durumları birebir geri getirmedi.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Rankings
        WHERE PlayAwardCategoryId = @DefaultCandidateId
          AND IsPublished = 1
          AND NumberOfActiveVote = 1
          AND ArithmeticMean = 8
    )
        THROW 52513, N'FAIL: Ranking projeksiyonu reaktivasyondan sonra yenilenmedi.', 1;

    INSERT INTO @Results VALUES
        (5, N'PASS', N'IsActive=1: yalnız lifecycle tarafından kapatılan kayıtlar önceki aktiflikleriyle geri açıldı; ranking yenilendi.');

    DELETE FROM dbo.Form WHERE Id = @FormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Form
        WHERE Id = @FormId AND IsPublished = 0 AND IsActive = 0
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 0
    )
        THROW 52514, N'FAIL: Form DELETE soft-delete yaşam döngüsünü çalıştırmadı.', 1;

    UPDATE dbo.Form
    SET IsPublished = 1, IsActive = 1, UpdatedDate = @Now
    WHERE Id = @FormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Form
        WHERE Id = @FormId AND IsPublished = 1 AND IsActive = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 1
    )
        THROW 52515, N'FAIL: Form soft-delete restore akışı başarısız.', 1;

    INSERT INTO @Results VALUES
        (6, N'PASS', N'DELETE fiziksel silmedi; Form soft-delete oldu, oyun pasifleşti ve explicit restore ile geri açıldı.');

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
        PremiereDate, Display, ApplicantName, ApplicantRole, Phone,
        Email, Director, IsActive, IsPublished
    )
    VALUES
    (
        @InactiveFormId, N'FT9002', CONVERT(datetime2, '2026-03-16T12:00:00'),
        N'Başlangıçta Pasif Form', N'Pasif Form Tiyatrosu',
        CONVERT(date, '2026-03-02'), N'[]', N'Pasif Başvuran', N'Yapımcı',
        N'05550000003', N'pasif-form@afife.test', N'Pasif Yönetmen', 0, 1
    );

    IF EXISTS (SELECT 1 FROM dbo.Plays WHERE SourceFormId = @InactiveFormId)
        THROW 52516, N'FAIL: Başlangıçta pasif Form için oyun oluşturuldu.', 1;

    UPDATE dbo.Form SET IsActive = 1 WHERE Id = @InactiveFormId;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Plays
        WHERE SourceFormId = @InactiveFormId
          AND RecordType = 0 AND IsPublished = 1 AND IsActive = 1
    )
        THROW 52517, N'FAIL: Pasif Form aktive edilince oyun oluşturulmadı.', 1;

    INSERT INTO @Results VALUES
        (7, N'PASS', N'Başlangıçta IsActive=0 Form oyun oluşturmadı; aktive edilince oyun ve kategori akışı başladı.');

    SELECT ScenarioOrder, Result, Scenario FROM @Results ORDER BY ScenarioOrder;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* A Form outside every published season is valid and remains unassigned. */
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
        PremiereDate, Display, ApplicantName, ApplicantRole, Phone,
        Email, Director, IsActive, IsPublished
    )
    VALUES
    (
        'fa000000-0000-0000-0000-000000000003', N'FT9003',
        CONVERT(datetime2, '2035-03-16T12:00:00'), N'Sezonsuz Form',
        N'Sezonsuz Tiyatro', CONVERT(date, '2035-03-02'), N'[]',
        N'Test', N'Yapımcı', N'05550000004', N'sezonsuz@afife.test',
        N'Yönetmen', 1, 1
    );

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Form
        WHERE Id = 'fa000000-0000-0000-0000-000000000003'
          AND SeasonId IS NULL
          AND IsPublished = 1
    )
        THROW 52518, N'FAIL: Sezon dışı Form kaydı SeasonId NULL olarak oluşturulmadı.', 1;

    SELECT N'PASS' AS Result, N'Sezon dışındaki CreatedDate ile Form kaydedildi ve SeasonId NULL kaldı.' AS Scenario;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
/* A visible child cannot be added while the source Form is inactive. */
DECLARE @InactiveWriteRejected bit = 0;
DECLARE @GuardFormId uniqueidentifier = 'fa000000-0000-0000-0000-000000000004';
DECLARE @GuardPlayId uniqueidentifier;
DECLARE @GuardJuryId uniqueidentifier;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT TOP (1) @GuardJuryId = Id
    FROM dbo.Users
    WHERE RoleCode = 2 AND IsPublished = 1 AND IsActive = 1
    ORDER BY Id;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
        PremiereDate, Display, ApplicantName, ApplicantRole, Phone,
        Email, Director, IsActive, IsPublished
    )
    VALUES
    (
        @GuardFormId, N'FT9004', CONVERT(datetime2, '2026-03-17T12:00:00'),
        N'Pasif Yazma Koruma Oyunu', N'Koruma Tiyatrosu',
        CONVERT(date, '2026-03-03'), N'[]', N'Test', N'Yapımcı',
        N'05550000005', N'koruma@afife.test', N'Yönetmen', 1, 1
    );

    SELECT @GuardPlayId = Id FROM dbo.Plays WHERE SourceFormId = @GuardFormId;
    UPDATE dbo.Form SET IsActive = 0 WHERE Id = @GuardFormId;

    INSERT INTO dbo.JuryGameTicketFees
        (Id, UserId, PlayId, TicketFee, CreatedAt, CreatedBy, IsPublished)
    VALUES
        (NEWID(), @GuardJuryId, @GuardPlayId, 100.00,
         DATEADD(HOUR, 3, SYSUTCDATETIME()), @GuardJuryId, 1);
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52412 SET @InactiveWriteRejected = 1;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @InactiveWriteRejected = 0
    THROW 52519, N'FAIL: Pasif Form oyununa yayımlanmış bilet kaydı engellenmedi.', 1;

SELECT N'PASS' AS Result, N'Pasif Form oyununa yeni yayımlanmış bilet kaydı DB triggerı tarafından engellendi.' AS Scenario;
GO

SELECT
    N'PASS' AS Result,
    N'Tüm test transactionları rollback edildi; kalıcı test Form/Play satırı bırakılmadı.' AS Scenario,
    (SELECT COUNT_BIG(*) FROM dbo.Form
     WHERE Id IN
     (
         'fa000000-0000-0000-0000-000000000001',
         'fa000000-0000-0000-0000-000000000002',
         'fa000000-0000-0000-0000-000000000003',
         'fa000000-0000-0000-0000-000000000004'
     )) AS RemainingTestForms;
GO
