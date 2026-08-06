/*
    Existing Kunye Plays -> Form backfill

    Creates one Form row for every existing RecordType = 0 Play that does not
    already have a SourceFormId. Form.Id is intentionally the existing Play.Id.
    The Form INSTEAD OF INSERT trigger then links SourceFormId without creating
    a second Play for the same record.

    This script never changes Play values directly, never deletes rows, and
    excludes RecordType = 1 Admin plays. Run it only after Form lifecycle
    procedures/triggers are installed.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() NOT LIKE N'%Test%'
    THROW 53100, N'Bu backfill yalnızca adında Test geçen veritabanında çalıştırılabilir.', 1;

IF OBJECT_ID(N'dbo.Form', N'U') IS NULL OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
    THROW 53101, N'Form veya Plays tablosu bulunamadı. Önce migrationları çalıştırın.', 1;

IF OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays', N'P') IS NULL
    THROW 53102, N'Form senkronizasyon prosedürü bulunamadı. Önce programmability migrationını çalıştırın.', 1;

DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
DECLARE @CorrelationId uniqueidentifier = NEWID();
DECLARE @ApplicationPrefix char(2) = UPPER(LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 2));

IF EXISTS
(
    SELECT 1
    FROM dbo.Plays AS play
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE play.RecordType = 0 AND play.SourceFormId IS NOT NULL
)
    PRINT N'Zaten Form ile ilişkili Künye oyunları korunacak; yalnızca eksik eşleşmeler backfill edilecek.';

IF EXISTS
(
    SELECT 1
    FROM dbo.Plays AS play
    WHERE play.RecordType = 0
      AND play.SourceFormId IS NULL
    GROUP BY LOWER(LTRIM(RTRIM(play.PlayName))), LOWER(LTRIM(RTRIM(play.TheaterName)))
    HAVING COUNT_BIG(*) > 1
)
    THROW 53103, N'Aynı oyun adı ve tiyatro adına sahip birden fazla Künye oyunu var; otomatik eşleştirme güvenli değil.', 1;

DECLARE @Backfill TABLE
(
    RowNo int NOT NULL PRIMARY KEY,
    PlayId uniqueidentifier NOT NULL UNIQUE,
    ApplicationNumber nvarchar(6) NOT NULL,
    CreatedDate datetime NULL,
    PlayName nvarchar(255) NOT NULL,
    TheaterName nvarchar(255) NOT NULL,
    Phone nvarchar(20) NOT NULL,
    ContactPersonName nvarchar(100) NOT NULL,
    ContactPersonPhone nvarchar(20) NOT NULL,
    Email nvarchar(150) NOT NULL,
    IsPublished bit NOT NULL,
    IsActive bit NOT NULL
);

INSERT INTO @Backfill
(
    RowNo, PlayId, ApplicationNumber, CreatedDate, PlayName, TheaterName,
    Phone, ContactPersonName, ContactPersonPhone, Email, IsPublished, IsActive
)
SELECT
    ROW_NUMBER() OVER (ORDER BY play.CreatedAt, play.Id),
    play.Id,
    N'XX0000',
    CONVERT(datetime, play.CreatedAt),
    play.PlayName,
    play.TheaterName,
    LEFT(COALESCE(NULLIF(play.Phone, N''), N'5550000000'), 20),
    LEFT(COALESCE(NULLIF(play.ContactPersonName, N''), N'Künye Başvurusu'), 100),
    LEFT(COALESCE(NULLIF(play.ContactPersonPhone, N''), play.Phone, N'5550000000'), 20),
    LEFT(COALESCE(NULLIF(play.Email, N''), N'backfill@afife.test'), 150),
    play.IsPublished,
    play.IsActive
FROM dbo.Plays AS play
WHERE play.RecordType = 0
  AND play.SourceFormId IS NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Form AS formRecord WHERE formRecord.Id = play.Id);

IF EXISTS (SELECT 1 FROM @Backfill WHERE RowNo > 9999)
    THROW 53104, N'Form ApplicationNumber üretimi için 9999 kayıt sınırı aşıldı.', 1;

WHILE EXISTS
(
    SELECT 1
    FROM @Backfill AS seed
    INNER JOIN dbo.Form AS existing
        ON existing.ApplicationNumber =
           @ApplicationPrefix + RIGHT('0000' + CONVERT(varchar(4), seed.RowNo), 4)
)
BEGIN
    SET @ApplicationPrefix = UPPER(LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 2));
END;

UPDATE @Backfill
SET ApplicationNumber =
    @ApplicationPrefix + RIGHT('0000' + CONVERT(varchar(4), RowNo), 4);

EXEC sys.sp_set_session_context @key=N'AdminCorrelationId', @value=@CorrelationId;
EXEC sys.sp_set_session_context @key=N'AdminUsername', @value=N'kunye-form-backfill';
EXEC sys.sp_set_session_context @key=N'AdminOperationName', @value=N'Mevcut Künye oyunlarını Form kayıtlarına eşleme';
EXEC sys.sp_set_session_context @key=N'AdminApplication', @value=N'AfifeAdmin-TestBackfill';
EXEC sys.sp_set_session_context @key=N'AdminRequestPath', @value=N'scripts/backfill-forms-for-kunye-plays.sql';

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
        TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
        Phone, Email, Director, ContactName, ContactPhone, LeadActress,
        LeadActor, SupportActress, SupportActor, StageDesign, ClothesDesign,
        LightDesign, StageMusic, Choreography, IsPublished, IsActive
    )
    SELECT
        seed.PlayId,
        seed.ApplicationNumber,
        seed.CreatedDate,
        NULL,
        LEFT(seed.PlayName, 500),
        LEFT(seed.TheaterName, 500),
        CONVERT(date, COALESCE(seed.CreatedDate, @Now)),
        N'[{"Location":"Backfill Sahne","Date":"08/11/2025","Time":"20:00"}]',
        LEFT(seed.ContactPersonName, 100),
        N'İzleyici',
        seed.Phone,
        seed.Email,
        N'Backfill Yönetmeni',
        seed.ContactPersonName,
        seed.ContactPersonPhone,
        NULL,
        NULL,
        NULL,
        NULL,
        N'{"Name":"Sahne Tasarımı","Role":"Backfill","ImageUrl":"","Base64":""}',
        N'{"Name":"Kıyafet Tasarımı","Role":"Backfill","ImageUrl":"","Base64":""}',
        N'{"Name":"Işık Tasarımı","Role":"Backfill","ImageUrl":"","Base64":""}',
        N'{"Name":"Sahne Müziği","Role":"Backfill","ImageUrl":"","Base64":""}',
        N'[{"Name":"Koreografi"}]',
        seed.IsPublished,
        seed.IsActive
    FROM @Backfill AS seed;

    COMMIT TRANSACTION;

    SELECT
        COUNT(*) AS BackfilledFormCount,
        SUM(CASE WHEN formRecord.SeasonId IS NOT NULL THEN 1 ELSE 0 END) AS SeasonAssignedCount,
        SUM(CASE WHEN play.SourceFormId = formRecord.Id THEN 1 ELSE 0 END) AS LinkedPlayCount
    FROM dbo.Form AS formRecord
    INNER JOIN @Backfill AS seed ON seed.PlayId = formRecord.Id
    LEFT JOIN dbo.Plays AS play ON play.Id = seed.PlayId;

    SELECT
        play.Id AS PlayId,
        play.PlayName,
        formRecord.Id AS FormId,
        formRecord.ApplicationNumber,
        formRecord.SeasonId,
        play.SourceFormId,
        play.RecordType,
        play.IsPublished,
        play.IsActive
    FROM dbo.Plays AS play
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    INNER JOIN @Backfill AS seed ON seed.PlayId = play.Id
    ORDER BY play.CreatedAt, play.Id;
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
