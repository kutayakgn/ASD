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
DECLARE @InactiveFormId uniqueidentifier = '33333333-3333-3333-3333-333333333333';
DECLARE @InactivePlayId uniqueidentifier = '44444444-4444-4444-4444-444444444444';
DECLARE @InactiveDirectorId uniqueidentifier = '55555555-5555-5555-5555-555555555555';
DECLARE @JuryId uniqueidentifier = '66666666-6666-6666-6666-666666666666';

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

INSERT INTO dbo.Form
(
    Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
    TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
    Phone, Email, Director, ContactName, ContactPhone,
    IsPublished, IsActive
)
VALUES
(
    @InactiveFormId, N'Q99997', SYSDATETIME(), SYSDATETIME(),
    N'Pasif Şirket Test Oyunu', N'Pasif Şirket Test Tiyatrosu',
    CONVERT(date, SYSDATETIME()), N'[]', N'Test Başvuran', N'Yetkili',
    N'5550000001', N'pasif-upgrade-test@example.com', N'Pasif Legacy Yönetmen',
    N'Test İletişim', N'5550000001', 1, 0
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

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = 1;

INSERT INTO dbo.Plays
(
    Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Slug, TheaterName, Phone, ContactPersonName,
    ContactPersonPhone, Address, Email, JuriOylamaStatus,
    KunyeGirisStatus, RecordType, SourceFormId, IsActive
)
VALUES
(
    @InactivePlayId, N'Pasif Şirket Test Oyunu', 1, SYSDATETIME(), NULL, NULL, NULL,
    1, N'pasif-sirket-test-oyunu', N'Pasif Şirket Test Tiyatrosu',
    N'5550000001', N'Test İletişim', N'5550000001', NULL,
    N'pasif-upgrade-test@example.com', 0, 0, 0, @InactiveFormId, 0
);

INSERT INTO dbo.PlayAwardCategories
(
    Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, IsActive, Candidate, AwardCategoryCode,
    IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
)
VALUES
(
    @InactiveDirectorId, @InactivePlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 1, N'Pasif Legacy Yönetmen', 1002, 1, NULL, 0, NULL, 0
);

INSERT INTO dbo.Users
(
    Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
    CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode,
    GroupCode, PhotoImageId, IsActive, IsJuryPresident
)
VALUES
(
    @JuryId, N'Test', N'Jüri', NULL, N'upgrade-test-jury', N'not-a-real-hash',
    N'upgrade-jury@example.com', SYSDATETIME(), NULL, NULL, NULL,
    1, 2, NULL, NULL, 1, 0
);

INSERT INTO dbo.JuryVotes
(
    Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Score, JuryId, IsActive
)
VALUES
(
    NEWID(), @InactiveDirectorId, SYSDATETIME(), @JuryId, NULL, NULL,
    1, 5, @JuryId, 1
);

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = NULL;

/* Reproduce the exact obsolete company index from SQL error 2601. */
CREATE UNIQUE NONCLUSTERED INDEX
    UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode
ON dbo.PlayAwardCategories (PlayId, AwardCategoryCode)
WHERE IsCurrent = 1 AND IsPublished = 1;
