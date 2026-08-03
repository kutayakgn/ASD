SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Seasons', N'U') IS NULL
        THROW 51910, N'dbo.Seasons tablosu bulunamadı. Önce create-seasons-and-statistics.sql çalıştırılmalıdır.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Seasons
        WHERE SeasonStartDate >= SeasonEndDate
           OR KunyeRegistrationStartDate < SeasonStartDate
           OR KunyeRegistrationStartDate >= KunyeRegistrationEndDate
           OR KunyeRegistrationEndDate > SeasonEndDate
           OR VotingStartDate < SeasonStartDate
           OR VotingStartDate >= VotingEndDate
           OR VotingEndDate > SeasonEndDate
    )
        THROW 51911, N'Mevcut Seasons kayıtlarından biri yeni tarih kurallarını ihlal ediyor. Hatalı kayıtları düzeltmeden constraint güncellenemez.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Seasons AS firstSeason
        INNER JOIN dbo.Seasons AS secondSeason
            ON firstSeason.Id < secondSeason.Id
           AND firstSeason.IsPublished = 1
           AND secondSeason.IsPublished = 1
           AND firstSeason.SeasonStartDate <= secondSeason.SeasonEndDate
           AND firstSeason.SeasonEndDate >= secondSeason.SeasonStartDate
    )
        THROW 51912, N'Mevcut yayımlanmış sezonlardan en az ikisi çakışıyor veya ortak sınır tarihine sahip. Kayıtları düzeltmeden overlap kuralı etkinleştirilemez.', 1;
    IF OBJECT_ID(N'dbo.CK_Seasons_SeasonDateRange', N'C') IS NOT NULL
        ALTER TABLE dbo.Seasons DROP CONSTRAINT CK_Seasons_SeasonDateRange;

    IF OBJECT_ID(N'dbo.CK_Seasons_KunyeRegistrationDateRange', N'C') IS NOT NULL
        ALTER TABLE dbo.Seasons DROP CONSTRAINT CK_Seasons_KunyeRegistrationDateRange;

    IF OBJECT_ID(N'dbo.CK_Seasons_VotingDateRange', N'C') IS NOT NULL
        ALTER TABLE dbo.Seasons DROP CONSTRAINT CK_Seasons_VotingDateRange;

    ALTER TABLE dbo.Seasons WITH CHECK
        ADD CONSTRAINT CK_Seasons_SeasonDateRange
        CHECK (SeasonStartDate < SeasonEndDate);

    ALTER TABLE dbo.Seasons WITH CHECK
        ADD CONSTRAINT CK_Seasons_KunyeRegistrationDateRange
        CHECK
        (
            KunyeRegistrationStartDate >= SeasonStartDate
            AND KunyeRegistrationStartDate < KunyeRegistrationEndDate
            AND KunyeRegistrationEndDate <= SeasonEndDate
        );

    ALTER TABLE dbo.Seasons WITH CHECK
        ADD CONSTRAINT CK_Seasons_VotingDateRange
        CHECK
        (
            VotingStartDate >= SeasonStartDate
            AND VotingStartDate < VotingEndDate
            AND VotingEndDate <= SeasonEndDate
        );

    ALTER TABLE dbo.Seasons CHECK CONSTRAINT
        CK_Seasons_SeasonDateRange,
        CK_Seasons_KunyeRegistrationDateRange,
        CK_Seasons_VotingDateRange;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
GO
