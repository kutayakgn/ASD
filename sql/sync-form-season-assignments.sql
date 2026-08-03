SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Form', N'U') IS NULL OR OBJECT_ID(N'dbo.Seasons', N'U') IS NULL
    THROW 52500, N'Form ve Seasons tabloları bulunmalıdır.', 1;
GO

DECLARE @SeasonDefault sysname;
SELECT @SeasonDefault = defaultConstraint.name
FROM sys.default_constraints AS defaultConstraint
INNER JOIN sys.columns AS columnInfo
    ON columnInfo.object_id = defaultConstraint.parent_object_id
   AND columnInfo.column_id = defaultConstraint.parent_column_id
WHERE defaultConstraint.parent_object_id = OBJECT_ID(N'dbo.Form')
  AND columnInfo.name = N'SeasonId';

IF @SeasonDefault IS NOT NULL
BEGIN
    DECLARE @DropDefaultSql nvarchar(max) =
        N'ALTER TABLE dbo.Form DROP CONSTRAINT ' + QUOTENAME(@SeasonDefault) + N';';
    EXEC sys.sp_executesql @DropDefaultSql;
END;

ALTER TABLE dbo.Form ALTER COLUMN SeasonId uniqueidentifier NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ReassignFormSeasons
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;

        UPDATE formRecord
        SET SeasonId = selectedSeason.Id
        FROM dbo.Form AS formRecord
        OUTER APPLY
        (
            SELECT TOP (1) season.Id
            FROM dbo.Seasons AS season
            WHERE season.IsPublished = 1
              AND formRecord.CreatedDate IS NOT NULL
              AND CAST(formRecord.CreatedDate AS date) >= season.SeasonStartDate
              AND CAST(formRecord.CreatedDate AS date) < season.SeasonEndDate
            ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
        ) AS selectedSeason
        WHERE formRecord.SeasonId <> selectedSeason.Id
           OR (formRecord.SeasonId IS NULL AND selectedSeason.Id IS NOT NULL)
           OR (formRecord.SeasonId IS NOT NULL AND selectedSeason.Id IS NULL);

        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize
ON dbo.Form
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'FormSeasonAssignmentSyncInProgress')) = 1
    BEGIN
        UPDATE target
        SET SeasonId = changed.SeasonId
        FROM dbo.Form AS target
        INNER JOIN inserted AS changed ON changed.Id = target.Id;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        LEFT JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE previous.Id IS NOT NULL
          AND previous.Id <> changed.Id
    )
        THROW 52404, N'Form.Id oluşturulduktan sonra değiştirilemez.', 1;

    UPDATE target
    SET
        ApplicationNumber = changed.ApplicationNumber,
        SeasonId = season.Id,
        CreatedDate = changed.CreatedDate,
        UpdatedDate = changed.UpdatedDate,
        RepertoireName = changed.RepertoireName,
        TheatreName = changed.TheatreName,
        PremiereDate = changed.PremiereDate,
        Display = changed.Display,
        ApplicantName = changed.ApplicantName,
        ApplicantRole = changed.ApplicantRole,
        Phone = changed.Phone,
        Email = changed.Email,
        Director = changed.Director,
        ContactName = changed.ContactName,
        ContactPhone = changed.ContactPhone,
        LeadActress = changed.LeadActress,
        LeadActor = changed.LeadActor,
        SupportActress = changed.SupportActress,
        SupportActor = changed.SupportActor,
        StageDesign = changed.StageDesign,
        ClothesDesign = changed.ClothesDesign,
        LightDesign = changed.LightDesign,
        StageMusic = changed.StageMusic,
        Choreography = changed.Choreography,
        IsActive = changed.IsActive,
        IsPublished = changed.IsPublished
    FROM dbo.Form AS target
    INNER JOIN inserted AS changed ON changed.Id = target.Id
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, SeasonId, CreatedDate, UpdatedDate,
        RepertoireName, TheatreName, PremiereDate, Display, ApplicantName,
        ApplicantRole, Phone, Email, Director, ContactName, ContactPhone,
        LeadActress, LeadActor, SupportActress, SupportActor, StageDesign,
        ClothesDesign, LightDesign, StageMusic, Choreography,
        IsActive, IsPublished
    )
    SELECT
        changed.Id, changed.ApplicationNumber, season.Id,
        changed.CreatedDate, changed.UpdatedDate,
        changed.RepertoireName, changed.TheatreName, changed.PremiereDate,
        changed.Display, changed.ApplicantName, changed.ApplicantRole,
        changed.Phone, changed.Email, changed.Director,
        changed.ContactName, changed.ContactPhone,
        changed.LeadActress, changed.LeadActor,
        changed.SupportActress, changed.SupportActor,
        changed.StageDesign, changed.ClothesDesign, changed.LightDesign,
        changed.StageMusic, changed.Choreography,
        changed.IsActive, changed.IsPublished
    FROM inserted AS changed
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form AS target WHERE target.Id = changed.Id
    );

    EXEC dbo.usp_SynchronizeFormsToPlays;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_ReassignForms
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    EXEC dbo.usp_ReassignFormSeasons;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;

    EXEC dbo.usp_ReassignFormSeasons;
END;
GO
EXEC dbo.usp_ReassignFormSeasons;
GO

SELECT
    formRecord.Id,
    formRecord.ApplicationNumber,
    formRecord.CreatedDate,
    formRecord.SeasonId
FROM dbo.Form AS formRecord
ORDER BY formRecord.CreatedDate DESC, formRecord.Id;
GO

-- Run sql/create-admin-audit-logging.sql after this file so procedure/trigger
-- side effects continue to be captured in AdminLogs.
