SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

BEGIN TRANSACTION;

DECLARE @FormId uniqueidentifier = NEWID();
DECLARE @PlayId uniqueidentifier = NEWID();

INSERT INTO dbo.Form
(
    Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
    TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
    Phone, Email, Director, ContactName, ContactPhone, LeadActress,
    LeadActor, SupportActress, SupportActor, StageDesign, ClothesDesign,
    LightDesign, StageMusic, Choreography, YoungGenerationArtist,
    IsPublished, IsActive
)
VALUES
(
    @FormId, N'Q99999', SYSDATETIME(), NULL, N'Pasif Form Test Oyunu',
    N'Pasif Form Test Tiyatrosu', CONVERT(date, SYSDATETIME()), N'[]',
    N'Test Başvuran', N'Yetkili', N'5550000000', N'pasif@example.com',
    N'Test Yönetmen', N'Test İletişim', N'5550000000', NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0
);

INSERT INTO dbo.Plays
(
    Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Slug, TheaterName, Phone, ContactPersonName,
    ContactPersonPhone, Address, Email, JuriOylamaStatus,
    KunyeGirisStatus, RecordType, SourceFormId, IsActive
)
VALUES
(
    @PlayId, N'Pasif Form Test Oyunu', 1, SYSDATETIME(), NULL, NULL, NULL,
    1, CONCAT('pasif-form-test-', LEFT(CONVERT(varchar(36), @PlayId), 8)),
    N'Pasif Form Test Tiyatrosu', N'5550000000', N'Test İletişim',
    N'5550000000', NULL, N'pasif@example.com', 0, 0, 0, @FormId, 0
);

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId
      AND AwardCategoryCode = 1001
      AND RoleCode = 0
      AND IsPublished = 0
      AND IsActive = 0
)
    THROW 52995, N'Pasif Form oyununun 1001 kaydı pasif oluşturulmadı.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND IsPublished = 1
)
    THROW 52996, N'Pasif Form kaynağına yayımlanmış kategori oluşturuldu.', 1;

ROLLBACK TRANSACTION;
