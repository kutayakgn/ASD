SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.usp_ReassignFormSeasons', N'P') IS NULL
   OR OBJECT_ID(N'dbo.TR_Seasons_ReassignForms', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.Form', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Seasons', N'U') IS NULL
    THROW 52530, N'Önce sync-form-season-assignments.sql çalıştırılmalıdır.', 1;
GO

DECLARE @FormId uniqueidentifier = 'fa000000-0000-0000-0000-000000000030';
DECLARE @SeasonId uniqueidentifier = 'fa000000-0000-0000-0000-000000000031';

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Seasons
        WHERE IsPublished = 1
          AND SeasonStartDate <= CONVERT(date, '2091-05-01')
          AND SeasonEndDate >= CONVERT(date, '2090-09-01')
    )
        THROW 52531, N'Test için ayrılan 2090/2091 tarih aralığında mevcut sezon var.', 1;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
        PremiereDate, Display, ApplicantName, ApplicantRole, Phone,
        Email, Director, IsActive, IsPublished
    )
    VALUES
    (
        @FormId, N'FS9001', CONVERT(datetime2, '2090-10-15T12:00:00'),
        N'Sezon Eşleştirme Testi', N'Test Tiyatrosu', CONVERT(date, '2090-10-01'),
        N'[]', N'Test Başvuran', N'Yapımcı', N'05550000030',
        N'season-sync@afife.test', N'Test Yönetmen', 0, 1
    );

    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @FormId AND SeasonId IS NULL)
        THROW 52532, N'FAIL: Sezon bulunmayan Form için SeasonId NULL olmadı.', 1;

    INSERT INTO dbo.Seasons
    (
        Id, SeasonStartDate, SeasonEndDate,
        KunyeRegistrationStartDate, KunyeRegistrationEndDate,
        VotingStartDate, VotingEndDate,
        PlayCount, ActivePlayCount, VoteCount, IsPublished
    )
    VALUES
    (
        @SeasonId, CONVERT(date, '2090-09-01'), CONVERT(date, '2091-05-01'),
        CONVERT(date, '2090-09-01'), CONVERT(date, '2090-12-31'),
        CONVERT(date, '2091-01-01'), CONVERT(date, '2091-04-30'),
        0, 0, 0, 1
    );

    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @FormId AND SeasonId = @SeasonId)
        THROW 52533, N'FAIL: Sezon eklenince Form yeni sezona atanmadı.', 1;

    UPDATE dbo.Seasons
    SET SeasonStartDate = CONVERT(date, '2092-09-01'),
        SeasonEndDate = CONVERT(date, '2093-05-01'),
        KunyeRegistrationStartDate = CONVERT(date, '2092-09-01'),
        KunyeRegistrationEndDate = CONVERT(date, '2092-12-31'),
        VotingStartDate = CONVERT(date, '2093-01-01'),
        VotingEndDate = CONVERT(date, '2093-04-30')
    WHERE Id = @SeasonId;

    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @FormId AND SeasonId IS NULL)
        THROW 52534, N'FAIL: Sezon tarihleri değişince eşleşmeyen Form SeasonId NULL olmadı.', 1;

    UPDATE dbo.Seasons
    SET SeasonStartDate = CONVERT(date, '2090-09-01'),
        SeasonEndDate = CONVERT(date, '2091-05-01'),
        KunyeRegistrationStartDate = CONVERT(date, '2090-09-01'),
        KunyeRegistrationEndDate = CONVERT(date, '2090-12-31'),
        VotingStartDate = CONVERT(date, '2091-01-01'),
        VotingEndDate = CONVERT(date, '2091-04-30')
    WHERE Id = @SeasonId;

    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @FormId AND SeasonId = @SeasonId)
        THROW 52535, N'FAIL: Sezon tarihleri geri alınınca Form yeniden atanmadı.', 1;

    UPDATE dbo.Seasons SET IsPublished = 0 WHERE Id = @SeasonId;

    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @FormId AND SeasonId IS NULL)
        THROW 52536, N'FAIL: Sezon soft-delete edilince Form SeasonId NULL olmadı.', 1;

    SELECT N'PASS' AS Result,
           N'Sezon create/update/soft-delete işlemleri Form.SeasonId değerini doğru atadı veya NULL yaptı.' AS Scenario;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
