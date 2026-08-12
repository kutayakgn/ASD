SET NOCOUNT ON;
SET XACT_ABORT ON;

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
    N'[{"Name":"Kadın Aday","Role":"Kadın Rol","ImageUrl":"kadin.png","Base64":"' + @PngBase64 + N'"}]',
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
          (1001, 1002, 1003, 1004, 1007, 1008, 1009, 1010, 1011, 1012)
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

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Images AS image ON image.Id = candidate.PhotoImageId
    WHERE play.SourceFormId = @FormId
      AND candidate.AwardCategoryCode = 1012
      AND image.ContentType = N'image/png'
      AND DATALENGTH(image.ImageData) > 0
)
    THROW 52991, N'1012 görseli oluşmadı.', 1;

ROLLBACK TRANSACTION;
