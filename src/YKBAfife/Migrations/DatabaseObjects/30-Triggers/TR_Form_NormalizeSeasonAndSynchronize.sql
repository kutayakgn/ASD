CREATE OR ALTER TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize
ON dbo.Form
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* SQL fires statement triggers even when no rows match. An empty JSON
       scope can become NULL, which the maintenance procedure treats as all. */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

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
        YoungGenerationArtist = changed.YoungGenerationArtist,
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
        YoungGenerationArtist,
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
        changed.YoungGenerationArtist,
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

    /* A reverse synchronization has already made Form authoritative for this
       statement. Running the forward procedure here would re-enter the graph. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) <> 1
       OR SESSION_CONTEXT(N'PlayToFormSyncInProgress') IS NULL
    BEGIN
        DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM inserted FOR JSON PATH);
        EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
    END;
END;
