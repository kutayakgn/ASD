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
DECLARE @CandidateId uniqueidentifier;

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
    @FormId, N'Q99998', SYSDATETIME(), NULL, N'Pasif Form 1001 Migration Testi',
    N'Pasif Form 1001 Tiyatrosu', CONVERT(date, SYSDATETIME()), N'[]',
    N'Test Başvuran', N'Yetkili', N'5550000000', N'pasif-1001@example.com',
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
    @PlayId, N'Pasif Form 1001 Migration Testi', 1, SYSDATETIME(), NULL, NULL, NULL,
    1, CONCAT('pasif-form-1001-', LEFT(CONVERT(varchar(36), @PlayId), 8)),
    N'Pasif Form 1001 Tiyatrosu', N'5550000000', N'Test İletişim',
    N'5550000000', NULL, N'pasif-1001@example.com', 0, 0, 0, @FormId, 0
);

SELECT @CandidateId = Id
FROM dbo.PlayAwardCategories
WHERE PlayId = @PlayId
  AND AwardCategoryCode = 1001
  AND RoleCode = 0;

IF @CandidateId IS NULL
    THROW 52997, N'1001 migration testi için sistem adayı oluşmadı.', 1;

/* Recreate the legacy company state that predates the inactive-source guard. */
DISABLE TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
    ON dbo.PlayAwardCategories;

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = 1;

UPDATE dbo.PlayAwardCategories
SET Candidate = N'Eski Tiyatro Adı',
    Role = NULL,
    IsPublished = 1,
    IsActive = 1
WHERE Id = @CandidateId;

EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = NULL;

ENABLE TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
    ON dbo.PlayAwardCategories;

/* The repaired EnforceCategory1001TheaterIdentity migration statement. */
EXEC sys.sp_set_session_context
    @key = N'FormLifecycleSyncInProgress', @value = 1;

BEGIN TRY
    UPDATE candidate
    SET Candidate = play.TheaterName,
        Role = N'Tiyatro',
        IsPublished = 0,
        IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    WHERE candidate.Id = @CandidateId;

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = NULL;
END TRY
BEGIN CATCH
    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = NULL;
    THROW;
END CATCH;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories
    WHERE Id = @CandidateId
      AND Candidate = N'Pasif Form 1001 Tiyatrosu'
      AND Role = N'Tiyatro'
      AND IsPublished = 0
      AND IsActive = 0
)
    THROW 52998, N'Pasif Form 1001 migration onarımı beklenen sonucu üretmedi.', 1;

ROLLBACK TRANSACTION;
