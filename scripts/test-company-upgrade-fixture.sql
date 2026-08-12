SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @FormId uniqueidentifier = '11111111-1111-1111-1111-111111111111';
DECLARE @PlayId uniqueidentifier = '22222222-2222-2222-2222-222222222222';

DISABLE TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize ON dbo.Form;

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
    @FormId, N'Q99998', SYSDATETIME(), SYSDATETIME(),
    N'Şirket Upgrade Test Oyunu', N'Şirket Upgrade Test Tiyatrosu',
    CONVERT(date, SYSDATETIME()), N'[]', N'Test Başvuran', N'Yetkili',
    N'5550000000', N'upgrade-test@example.com', N'Legacy Yönetmen',
    N'Test İletişim', N'5550000000', NULL, NULL, NULL,
    N'[{"Name":"Yardımcı Erkek Bir","Role":"Ortak Rol","ImageUrl":"","Base64":""},'
      + N'{"Name":"Yardımcı Erkek İki","Role":"Ortak Rol","ImageUrl":"","Base64":""}]',
    NULL, NULL, NULL, NULL, NULL, NULL, 1, 1
);

ENABLE TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize ON dbo.Form;

INSERT INTO dbo.Plays
(
    Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Slug, TheaterName, Phone, ContactPersonName,
    ContactPersonPhone, Address, Email, JuriOylamaStatus,
    KunyeGirisStatus, RecordType, SourceFormId, IsActive
)
VALUES
(
    @PlayId, N'Şirket Upgrade Test Oyunu', 1, SYSDATETIME(), NULL, NULL, NULL,
    1, N'sirket-upgrade-test-oyunu', N'Şirket Upgrade Test Tiyatrosu',
    N'5550000000', N'Test İletişim', N'5550000000', NULL,
    N'upgrade-test@example.com', 1, 1, 0, @FormId, 1
);

/* Reproduce the exact obsolete company index from SQL error 2601. */
CREATE UNIQUE NONCLUSTERED INDEX
    UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode
ON dbo.PlayAwardCategories (PlayId, AwardCategoryCode)
WHERE IsCurrent = 1 AND IsPublished = 1;
