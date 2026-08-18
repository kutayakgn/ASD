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
DECLARE @PngBase64 nvarchar(max) =
    N'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

INSERT dbo.Form
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
    @FormId, N'Z99999', SYSDATETIME(), SYSDATETIME(),
    N'Senkronizasyon Test Oyunu', N'Senkronizasyon Test Tiyatrosu',
    CONVERT(date, SYSDATETIME()), N'[]', N'Test Başvuran', N'Yetkili',
    N'5550000000', N'test@example.com', N'Test Yönetmen', N'Test İletişim',
    N'5550000000',
    N'[{"Name":"Kadın Aday Bir","Role":"Ortak Rol","ImageUrl":"kadin.png","Base64":"' + @PngBase64 + N'"},'
      + N'{"Name":"Kadın Aday İki","Role":"Ortak Rol","ImageUrl":"","Base64":""}]',
    N'[{"Name":"Erkek Aday","Role":"Erkek Rol","ImageUrl":"","Base64":""}]',
    NULL, NULL,
    N'[{"Name":"Sahne Bir"},{"Name":"Sahne İki"}]',
    N'[{"Name":"Giysi Bir"}]',
    N'[{"Name":"Işık Bir"}]',
    N'[{"Name":"Müzik Bir"}]',
    N'[{"Name":"Koreografi Bir"}]',
    N'[{"Name":"Genç Aday","Role":"Genç Rol","ImageUrl":"genc.png","Base64":"' + @PngBase64 + N'"}]',
    1, 1
);

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Plays
    WHERE SourceFormId = @FormId
      AND JuriOylamaStatus = 0
      AND KunyeGirisStatus = 0
)
    THROW 52989, N'Form kaydından oluşan oyunun jüri oylama ve künye giriş statüleri kapalı başlamadı.', 1;

SELECT candidate.AwardCategoryCode, candidate.Candidate, candidate.Role,
       candidate.RoleCode, image.ContentType, DATALENGTH(image.ImageData) AS ImageBytes
FROM dbo.Plays AS play
INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.PlayId = play.Id
LEFT JOIN dbo.Images AS image ON image.Id = candidate.PhotoImageId
WHERE play.SourceFormId = @FormId
ORDER BY candidate.AwardCategoryCode, candidate.RoleCode;

IF
(
    SELECT COUNT(*)
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    WHERE play.SourceFormId = @FormId
      AND candidate.AwardCategoryCode IN
          (1001, 1002, 1003, 1004, 1007, 1008, 1009, 1010, 1011)
) <> 11
    THROW 52990, N'Beklenen aday kategorileri oluşmadı.', 1;

IF
(
    SELECT COUNT(DISTINCT candidate.RoleCode)
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    WHERE play.SourceFormId = @FormId
      AND candidate.AwardCategoryCode = 1007
      AND candidate.RoleCode > 0
) <> 2
    THROW 52992, N'1007 adayları ayrı RoleCode değerleriyle oluşmadı.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    WHERE play.SourceFormId = @FormId
      AND candidate.AwardCategoryCode = 1012
)
    THROW 52991, N'Kaldırılmış 1012 kategorisi için aday oluşturuldu.', 1;

DECLARE @PlayId uniqueidentifier =
(
    SELECT Id FROM dbo.Plays WHERE SourceFormId = @FormId
);
DECLARE @FirstRoleCode int =
(
    SELECT RoleCode FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
      AND SourceFormCandidateOrder = 1 AND IsCurrent = 1
);
DECLARE @SecondRoleCode int =
(
    SELECT RoleCode FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
      AND SourceFormCandidateOrder = 2 AND IsCurrent = 1
);
DECLARE @FirstPhotoId uniqueidentifier =
(
    SELECT PhotoImageId FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
      AND SourceFormCandidateOrder = 1 AND IsCurrent = 1
);

IF @FirstRoleCode IS NULL OR @SecondRoleCode IS NULL OR @FirstRoleCode = @SecondRoleCode
    THROW 52993, N'Aynı rol adındaki Form adayları benzersiz RoleCode alamadı.', 1;

/* Recreate a legacy director row from the company database. The Form sync must
   normalize the single-slot category without failing with SQL error 51304. */
DISABLE TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
    ON dbo.PlayAwardCategories;

UPDATE dbo.PlayAwardCategories
SET Role = N'Legacy Yönetmen Rolü', RoleCode = 77
WHERE PlayId = @PlayId AND AwardCategoryCode = 1002 AND IsCurrent = 1;

ENABLE TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
    ON dbo.PlayAwardCategories;

UPDATE dbo.Form
SET Director = N'Formdan Güncel Yönetmen', UpdatedDate = SYSDATETIME()
WHERE Id = @FormId;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1002
      AND Candidate = N'Formdan Güncel Yönetmen'
      AND Role IS NULL AND RoleCode = 0
      AND IsCurrent = 1 AND IsPublished = 1
)
    THROW 52989, N'Legacy 1002 yönetmen kaydı kanonik tek slota dönüştürülmedi.', 1;

/* Play/PAC edits are one-way and must not mutate Form. */
UPDATE dbo.Plays SET PlayName = N'Admin Oyun Adı' WHERE Id = @PlayId;
UPDATE dbo.PlayAwardCategories
SET Candidate = N'Admin Aday Adı'
WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
  AND SourceFormCandidateOrder = 1 AND IsCurrent = 1;

IF EXISTS
(
    SELECT 1 FROM dbo.Form
    WHERE Id = @FormId
      AND (RepertoireName <> N'Senkronizasyon Test Oyunu'
           OR LeadActress LIKE N'%Admin Aday Adı%')
)
    THROW 52994, N'Play veya aday güncellemesi Form kaydına geri yazıldı.', 1;

/* Form owns mapped fields but must preserve immutable RoleCodes. */
UPDATE dbo.Form
SET RepertoireName = N'Formdan Güncellenen Oyun',
    LeadActress = N'[{"Name":"Form Aday Bir Yeni","Role":"Yeni Ortak Rol","ImageUrl":"yeni.png","Base64":"'
                + @PngBase64 + N'"},'
                + N'{"Name":"Form Aday İki Yeni","Role":"Yeni Ortak Rol","ImageUrl":"","Base64":""}]',
    UpdatedDate = SYSDATETIME()
WHERE Id = @FormId;

IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @PlayId AND PlayName = N'Formdan Güncellenen Oyun')
    THROW 52995, N'Form oyun adı Plays tablosuna yansımadı.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
      AND SourceFormCandidateOrder = 1 AND RoleCode = @FirstRoleCode
      AND Candidate = N'Form Aday Bir Yeni' AND Role = N'Yeni Ortak Rol'
      AND IsCurrent = 1 AND IsPublished = 1
)
OR NOT EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
      AND SourceFormCandidateOrder = 2 AND RoleCode = @SecondRoleCode
      AND Candidate = N'Form Aday İki Yeni' AND Role = N'Yeni Ortak Rol'
      AND IsCurrent = 1 AND IsPublished = 1
)
    THROW 52996, N'Form aday güncellemesi sabit RoleCode ile uygulanmadı.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Images AS image ON image.Id = candidate.PhotoImageId
    WHERE candidate.PlayId = @PlayId
      AND candidate.AwardCategoryCode = 1003
      AND candidate.SourceFormCandidateOrder = 1
      AND candidate.PhotoImageId <> @FirstPhotoId
      AND image.IsPublished = 1
      AND image.ContentType = N'image/png'
      AND DATALENGTH(image.ImageData) > 0
)
OR EXISTS (SELECT 1 FROM dbo.Images WHERE Id = @FirstPhotoId AND IsPublished = 1)
    THROW 52999, N'Form aday görseli Images ilişkisiyle yenilenmedi.', 1;

UPDATE dbo.Form SET IsActive = 0, UpdatedDate = SYSDATETIME() WHERE Id = @FormId;

IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 0)
   OR EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE PlayId = @PlayId AND IsPublished = 1)
    THROW 52997, N'Form pasifleştirme akışı bağımlı kayıtları pasifleştirmedi.', 1;

UPDATE dbo.Form SET IsActive = 1, UpdatedDate = SYSDATETIME() WHERE Id = @FormId;

IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @PlayId AND IsPublished = 1 AND IsActive = 1)
   OR NOT EXISTS
   (
       SELECT 1 FROM dbo.PlayAwardCategories
       WHERE PlayId = @PlayId AND AwardCategoryCode = 1003
         AND SourceFormCandidateOrder = 1 AND RoleCode = @FirstRoleCode
         AND IsPublished = 1 AND IsActive = 1 AND IsCurrent = 1
   )
    THROW 52998, N'Form yeniden aktifleştirme akışı kayıtları geri yüklemedi.', 1;

ROLLBACK TRANSACTION;
