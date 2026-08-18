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
DECLARE @RetiredCandidateId uniqueidentifier = '77777777-7777-7777-7777-777777777777';
DECLARE @RetiredImageId uniqueidentifier = '88888888-8888-8888-8888-888888888888';
DECLARE @DuplicateRoleCandidateOneId uniqueidentifier = '99999999-9999-9999-9999-999999999991';
DECLARE @DuplicateRoleCandidateTwoId uniqueidentifier = '99999999-9999-9999-9999-999999999992';
DECLARE @SharedRoleDifferentCandidateOneId uniqueidentifier = '99999999-9999-9999-9999-999999999993';
DECLARE @SharedRoleDifferentCandidateTwoId uniqueidentifier = '99999999-9999-9999-9999-999999999994';
DECLARE @LargeCandidatePhoto varbinary(max) =
    0x89504E470D0A1A0A + CONVERT(varbinary(max), REPLICATE('A', 5000));
DECLARE @LargeCandidateBase64 nvarchar(max) = CAST(N'' AS xml).value(
    'xs:base64Binary(sql:variable("@LargeCandidatePhoto"))', 'nvarchar(max)');

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
    N'Test İletişim', N'5550000000', NULL,
    N'[{"Name":"Erkek Aday Bir","Role":"Ortak Erkek Rol"},{"Name":"Erkek Aday İki","Role":"Ortak Erkek Rol"}]',
    N'[{"Name":"deneme","Role":"Yardımcı Rol"},{"Name":"deneme","Role":"Yardımcı Rol"}]',
    N'[{"Name":"Yardımcı Erkek Bir","Role":"Ortak Rol","ImageUrl":"buyuk-aday.png","Base64":"'
      + @LargeCandidateBase64 + N'"},'
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
    @PlayId, N'Şirket Upgrade Test Oyunu', 1, SYSDATETIME(), NULL, NULL, NULL,
    1, N'sirket-upgrade-test-oyunu', N'Şirket Upgrade Test Tiyatrosu',
    N'5550000000', N'Test İletişim', N'5550000000', NULL,
    N'upgrade-test@example.com', 1, 1, 0, @FormId, 1
);

/* Reproduces company data where two legacy slots share RoleCode=3. Updating
   both candidates to the same Form name used to fail V1.2.0 with index 2601. */
INSERT INTO dbo.PlayAwardCategories
(
    Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, IsActive, Candidate, AwardCategoryCode,
    IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
)
VALUES
(
    @DuplicateRoleCandidateOneId, @PlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 1, N'Eski Yardımcı Aday Bir', 1005, 1, N'Yardımcı Rol', 3, NULL, NULL
),
(
    @DuplicateRoleCandidateTwoId, @PlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 0, N'Eski Yardımcı Aday İki', 1005, 0, N'Yardımcı Rol', 3, NULL, NULL
);

/* Same play/category/RoleCode with different candidate names is valid. The
   legacy unique current-role index used to reject the second current row. */
INSERT INTO dbo.PlayAwardCategories
(
    Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, IsActive, Candidate, AwardCategoryCode,
    IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
)
VALUES
(
    @SharedRoleDifferentCandidateOneId, @PlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 1, N'Eski Erkek Aday Bir', 1004, 1, N'Ortak Erkek Rol', 17, NULL, NULL
),
(
    @SharedRoleDifferentCandidateTwoId, @PlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 0, N'Eski Erkek Aday İki', 1004, 0, N'Ortak Erkek Rol', 17, NULL, NULL
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

IF NOT EXISTS (SELECT 1 FROM dbo.AwardCategories WHERE CategoryCode = 1012)
BEGIN
    INSERT INTO dbo.AwardCategories
    (
        Id, CategoryName, CategoryCode, CreatedAt, CreatedBy,
        UpdatedAt, UpdatedBy, IsPublished, MultiCandidate, HasRoleAndPhoto
    )
    VALUES
    (
        '40000000-0000-0000-0000-000000000011',
        N'Yılın En Başarılı Genç Kuşak Sanatçısı', 1012,
        SYSDATETIME(), NULL, NULL, NULL, 1, 1, 1
    );
END;

INSERT INTO dbo.Images
(
    Id, FileName, ContentType, ImageData, CreatedAt, UpdatedAt,
    CreatedBy, UpdatedBy, IsPublished
)
VALUES
(
    @RetiredImageId, N'1012-test.png', N'image/png', 0x89504E470D0A1A0A,
    SYSDATETIME(), NULL, @JuryId, NULL, 1
);

INSERT INTO dbo.PlayAwardCategories
(
    Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, IsActive, Candidate, AwardCategoryCode,
    IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
)
VALUES
(
    @RetiredCandidateId, @PlayId, SYSDATETIME(), NULL, NULL, NULL,
    1, 1, N'Kaldırılacak Genç Aday', 1012, 1,
    N'Kaldırılacak Rol', 91, @RetiredImageId, 1
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

INSERT INTO dbo.JuryVotes
(
    Id, PlayAwardCategoryId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Score, JuryId, IsActive
)
VALUES
(
    NEWID(), @RetiredCandidateId, SYSDATETIME(), @JuryId, NULL, NULL,
    1, 4, @JuryId, 1
);

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = NULL;

/* Reproduce the exact obsolete company index from SQL error 2601. */
CREATE UNIQUE NONCLUSTERED INDEX
    UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode
ON dbo.PlayAwardCategories (PlayId, AwardCategoryCode)
WHERE IsCurrent = 1 AND IsPublished = 1;
