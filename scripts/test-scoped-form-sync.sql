/* Run only against a disposable, fully migrated local database with sqlcmd -I -b.
   Fixtures and their audit rows are rolled back. No trigger is disabled. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF NOT EXISTS
(
    SELECT 1 FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays')
      AND name = N'@FormIdsJson'
)
OR NOT EXISTS
(
    SELECT 1 FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.usp_SynchronizeFormCandidates')
      AND name = N'@FormIdsJson'
)
    THROW 53280, N'Scoped synchronization migration is not installed.', 1;

/* Validate both public entry points before opening the fixture transaction:
   THROW with XACT_ABORT ON can make an enclosing transaction uncommittable. */
DECLARE @BadScopes TABLE (ScopeJson nvarchar(max) NOT NULL);
INSERT @BadScopes VALUES
    (N'not json'), (N'{}'), (N'null'),
    (N'[{"Id":"not-a-guid"}]'), (N'[{"Other":"missing-id"}]'),
    (N'[{"Id":null}]'),
    (N'[{"Id":"00000000-0000-0000-0000-000000000000-extra"}]');
DECLARE @ProcedureName sysname, @BadScope nvarchar(max), @ValidationSql nvarchar(max);
DECLARE validation_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT entryPoint.ProcedureName, bad.ScopeJson
    FROM @BadScopes AS bad
    CROSS JOIN
    (
        VALUES (N'usp_SynchronizeFormsToPlays'), (N'usp_SynchronizeFormCandidates')
    ) AS entryPoint(ProcedureName);
OPEN validation_cursor;
FETCH NEXT FROM validation_cursor INTO @ProcedureName, @BadScope;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @ValidationSql = N'EXEC dbo.' + QUOTENAME(@ProcedureName)
            + N' @FormIdsJson = @Scope;';
        EXEC sys.sp_executesql @ValidationSql, N'@Scope nvarchar(max)', @Scope = @BadScope;
        THROW 53281, N'Invalid scope was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 52433 THROW;
    END CATCH;
    FETCH NEXT FROM validation_cursor INTO @ProcedureName, @BadScope;
END;
CLOSE validation_cursor;
DEALLOCATE validation_cursor;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @FirstForm uniqueidentifier = NEWID(), @SecondForm uniqueidentifier = NEWID(),
            @UnrelatedForm uniqueidentifier = NEWID(), @LegacyFirst uniqueidentifier = NEWID(),
            @LegacySecond uniqueidentifier = NEWID(), @LegacyPlay uniqueidentifier = NEWID();
    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @Suffix nvarchar(32) = REPLACE(CONVERT(nvarchar(36), @FirstForm), N'-', N'');
    DECLARE @Png nvarchar(max) =
        N'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    DECLARE @PhotoCandidates nvarchar(max) =
        N'[{"Name":"Scoped first actor","Role":"Lead","ImageUrl":"one.png","Base64":"'
        + @Png + N'"},{"Name":"Scoped second actor","Role":"Support","Base64":""}]';
    DECLARE @OnePhotoCandidate nvarchar(max) =
        N'[{"Name":"Scoped first actor","Role":"Lead","ImageUrl":"one.png","Base64":"'
        + @Png + N'"}]';

    /* One statement must propagate every inserted Form, not TOP(1)/a scalar Id. */
    INSERT dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
        TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
        Phone, Email, Director, ContactName, ContactPhone, LeadActress,
        LeadActor, SupportActress, SupportActor, StageDesign, ClothesDesign,
        LightDesign, StageMusic, Choreography, YoungGenerationArtist,
        IsPublished, IsActive
    )
    SELECT fixture.Id, fixture.ApplicationNumber, @Now, @Now,
        fixture.PlayName + @Suffix, N'Scoped theatre ' + @Suffix,
        CONVERT(date, @Now), N'[]', N'Scoped applicant', N'Contact',
        N'5550000000', N'scoped@example.invalid', fixture.Director,
        N'Scoped contact', N'5550000000', @PhotoCandidates,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 1
    FROM
    (
        VALUES
            (@FirstForm, N'SC1001', N'First scoped ', N'First director'),
            (@SecondForm, N'SC1002', N'Second scoped ', N'Second director'),
            (@UnrelatedForm, N'SC1003', N'Unrelated scoped ', N'Unrelated director')
    ) AS fixture(Id, ApplicationNumber, PlayName, Director);

    IF (SELECT COUNT(*) FROM dbo.Plays
        WHERE SourceFormId IN (@FirstForm, @SecondForm, @UnrelatedForm)) <> 3
        THROW 53282, N'Multirow Form insert did not create every Play.', 1;

    DECLARE @FirstPlay uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @FirstForm);
    DECLARE @SecondPlay uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @SecondForm);
    DECLARE @UnrelatedPlay uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @UnrelatedForm);
    IF (SELECT COUNT(*) FROM dbo.PlayAwardCategories
        WHERE PlayId IN (@FirstPlay, @SecondPlay, @UnrelatedPlay)
          AND AwardCategoryCode = 1003 AND IsCurrent = 1) <> 6
        THROW 53283, N'Multirow Form insert did not project all candidate slots.', 1;

    DECLARE @FirstDirector uniqueidentifier =
        (SELECT Id FROM dbo.PlayAwardCategories WHERE PlayId = @FirstPlay
         AND AwardCategoryCode = 1002 AND IsCurrent = 1);
    DECLARE @FirstActor uniqueidentifier =
        (SELECT Id FROM dbo.PlayAwardCategories WHERE PlayId = @FirstPlay
         AND AwardCategoryCode = 1003 AND SourceFormCandidateOrder = 1 AND IsCurrent = 1);
    DECLARE @FirstRoleCode int = (SELECT RoleCode FROM dbo.PlayAwardCategories WHERE Id = @FirstActor);
    DECLARE @FirstImage uniqueidentifier = (SELECT PhotoImageId FROM dbo.PlayAwardCategories WHERE Id = @FirstActor);
    DECLARE @RetiredActor uniqueidentifier =
        (SELECT Id FROM dbo.PlayAwardCategories WHERE PlayId = @FirstPlay
         AND AwardCategoryCode = 1003 AND SourceFormCandidateOrder = 2 AND IsCurrent = 1);

    IF @FirstDirector IS NULL OR @FirstImage IS NULL OR @RetiredActor IS NULL
        THROW 53284, N'Candidate/photo fixture was not created.', 1;

    /* Manually disabled candidates and Play workflow flags must survive edits. */
    UPDATE dbo.PlayAwardCategories SET IsActive = 0 WHERE Id = @FirstDirector;
    UPDATE dbo.Plays SET JuriOylamaStatus = 1, KunyeGirisStatus = 1 WHERE Id = @FirstPlay;

    DECLARE @UnrelatedCandidates TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @UnrelatedCandidates SELECT Id FROM dbo.PlayAwardCategories WHERE PlayId = @UnrelatedPlay;
    DECLARE @UnrelatedImages TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @UnrelatedImages SELECT DISTINCT PhotoImageId FROM dbo.PlayAwardCategories
        WHERE PlayId = @UnrelatedPlay AND PhotoImageId IS NOT NULL;
    DECLARE @UnrelatedRankings TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @UnrelatedRankings SELECT Id FROM dbo.Rankings WHERE PlayId = @UnrelatedPlay;
    DECLARE @UnrelatedFormBefore nvarchar(max) =
        (SELECT * FROM dbo.Form WHERE Id = @UnrelatedForm FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @UnrelatedPlayBefore nvarchar(max) =
        (SELECT * FROM dbo.Plays WHERE Id = @UnrelatedPlay FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @UnrelatedCandidatesBefore nvarchar(max) =
        (SELECT * FROM dbo.PlayAwardCategories WHERE PlayId = @UnrelatedPlay
         ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @UnrelatedImagesBefore nvarchar(max) =
        (SELECT image.* FROM dbo.Images AS image JOIN @UnrelatedImages AS saved ON saved.Id = image.Id
         ORDER BY image.Id FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @UnrelatedRankingsBefore nvarchar(max) =
        (SELECT * FROM dbo.Rankings WHERE PlayId = @UnrelatedPlay
         ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @ActionCorrelation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @ActionCorrelation;

    /* A one-Form edit may retire only that Form's removed source slot. */
    UPDATE dbo.Form SET LeadActress = @OnePhotoCandidate, UpdatedDate = @Now
    WHERE Id = @FirstForm;
    IF NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @RetiredActor
                   AND IsPublished = 0 AND IsActive = 0 AND IsCurrent = 0)
        THROW 53285, N'Removed slot was not retired within the affected Form.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @FirstActor
                   AND RoleCode = @FirstRoleCode AND PhotoImageId = @FirstImage
                   AND IsPublished = 1 AND IsCurrent = 1)
        THROW 53286, N'Unchanged scoped slot lost its identity, role or photo.', 1;
    IF (SELECT COUNT(*) FROM dbo.PlayAwardCategories
        WHERE PlayId = @SecondPlay AND AwardCategoryCode = 1003
          AND IsPublished = 1 AND IsActive = 1 AND IsCurrent = 1) <> 2
        THROW 53287, N'Single-Form retirement deactivated another Form candidate.', 1;

    /* One UPDATE statement must carry both Form IDs to both procedures. */
    UPDATE dbo.Form
    SET Director = CASE Id WHEN @FirstForm THEN N'First director revised'
                           ELSE N'Second director revised' END,
        UpdatedDate = @Now
    WHERE Id IN (@FirstForm, @SecondForm);
    IF NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @FirstDirector
                   AND Candidate = N'First director revised' AND Role IS NULL AND RoleCode = 0
                   AND IsPublished = 1 AND IsCurrent = 1 AND IsActive = 0)
       OR NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE PlayId = @SecondPlay
                      AND AwardCategoryCode = 1002 AND Candidate = N'Second director revised'
                      AND IsPublished = 1 AND IsCurrent = 1 AND IsActive = 1)
        THROW 53288, N'Multirow update lost a director or its manual activation state.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @FirstPlay
                   AND JuriOylamaStatus = 1 AND KunyeGirisStatus = 1)
        THROW 53289, N'Form update reset manually selected Play workflow flags.', 1;

    /* The unrelated Form, JSON/photos, candidate UpdatedAt and ranking rows
       must stay byte-for-byte identical, including their persistent IDs. */
    IF @UnrelatedFormBefore <>
       (SELECT * FROM dbo.Form WHERE Id = @UnrelatedForm FOR JSON PATH, INCLUDE_NULL_VALUES)
       OR @UnrelatedPlayBefore <>
       (SELECT * FROM dbo.Plays WHERE Id = @UnrelatedPlay FOR JSON PATH, INCLUDE_NULL_VALUES)
       OR @UnrelatedCandidatesBefore <>
       (SELECT * FROM dbo.PlayAwardCategories WHERE PlayId = @UnrelatedPlay
        ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)
       OR @UnrelatedImagesBefore <>
       (SELECT image.* FROM dbo.Images AS image JOIN @UnrelatedImages AS saved ON saved.Id = image.Id
        ORDER BY image.Id FOR JSON PATH, INCLUDE_NULL_VALUES)
       OR @UnrelatedRankingsBefore <>
       (SELECT * FROM dbo.Rankings WHERE PlayId = @UnrelatedPlay
        ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)
        THROW 53290, N'An unrelated Form, Play, candidate, photo or ranking changed.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.AdminLogs AS audit
        CROSS APPLY OPENJSON(CASE WHEN ISJSON(audit.EntityKey) = 1
                                 THEN audit.EntityKey ELSE N'[]' END)
            WITH (Id uniqueidentifier N'$.Id') AS entity
        WHERE audit.CorrelationId = @ActionCorrelation
          AND
          (
              (audit.TableName = N'Form' AND entity.Id = @UnrelatedForm)
              OR (audit.TableName = N'Plays' AND entity.Id = @UnrelatedPlay)
              OR (audit.TableName = N'PlayAwardCategories'
                  AND entity.Id IN (SELECT Id FROM @UnrelatedCandidates))
              OR (audit.TableName = N'Images' AND entity.Id IN (SELECT Id FROM @UnrelatedImages))
              OR (audit.TableName = N'Rankings' AND entity.Id IN (SELECT Id FROM @UnrelatedRankings))
          )
    )
        THROW 53291, N'Scoped update produced unrelated candidate/image/ranking audit work.', 1;

    /* Re-sending unchanged candidate JSON is a real Form write, but must not
       update a candidate/image/ranking merely to advance UpdatedAt. */
    DECLARE @NoOpCorrelation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @NoOpCorrelation;
    UPDATE dbo.Form SET LeadActress = LeadActress WHERE Id = @FirstForm;
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs WHERE CorrelationId = @NoOpCorrelation
               AND TableName IN (N'PlayAwardCategories', N'Images', N'Rankings'))
        THROW 53292, N'Unchanged candidate JSON still caused candidate/image/ranking writes.', 1;

    /* Explicit valid single/multiple scopes and [] must be idempotent. */
    DECLARE @SingleScope nvarchar(max) = (SELECT @FirstForm AS Id FOR JSON PATH);
    DECLARE @MultipleScope nvarchar(max) =
        (SELECT Id FROM dbo.Form WHERE Id IN (@FirstForm, @SecondForm) FOR JSON PATH);
    DECLARE @ExplicitCorrelation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @ExplicitCorrelation;
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @SingleScope;
    EXEC dbo.usp_SynchronizeFormCandidates @FormIdsJson = @MultipleScope;
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = N'[]';
    EXEC dbo.usp_SynchronizeFormCandidates @FormIdsJson = N'[]';
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs WHERE CorrelationId = @ExplicitCorrelation)
        THROW 53293, N'Idempotent or empty explicit scope still produced persistent writes.', 1;

    /* Preserve deactivation/reactivation, including manually disabled status. */
    UPDATE dbo.Form SET IsActive = 0 WHERE Id = @FirstForm;
    IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @FirstPlay AND IsActive = 0)
       OR EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE PlayId = @FirstPlay
                  AND (IsPublished = 1 OR IsActive = 1))
        THROW 53294, N'Scoped deactivation did not deactivate its dependent rows.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @SecondPlay AND IsActive = 1)
        THROW 53295, N'Scoped deactivation affected another Play.', 1;

    UPDATE dbo.Form SET IsActive = 1 WHERE Id = @FirstForm;
    IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @FirstPlay AND IsActive = 1
                   AND JuriOylamaStatus = 1 AND KunyeGirisStatus = 1)
       OR NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @FirstActor
                      AND IsPublished = 1 AND IsActive = 1 AND IsCurrent = 1
                      AND RoleCode = @FirstRoleCode AND PhotoImageId = @FirstImage)
       OR NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @FirstDirector
                      AND IsPublished = 1 AND IsActive = 0 AND IsCurrent = 1)
        THROW 53296, N'Scoped reactivation lost saved workflow/candidate status or photo.', 1;

    /* Create two unprojected historical Forms through the existing recursion
       guard. Their shared legacy match must remain ambiguous globally even
       when only one Form is selected for synchronization. */
    EXEC sys.sp_set_session_context @key = N'FormLifecycleSyncInProgress', @value = 1;
    INSERT dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
        PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email,
        Director, ContactName, ContactPhone, IsPublished, IsActive
    )
    SELECT fixture.Id, fixture.ApplicationNumber, @Now,
        N'Ambiguous legacy ' + @Suffix, N'Legacy theatre ' + @Suffix,
        CONVERT(date, @Now), N'[]', N'Legacy applicant', N'Contact',
        N'5550000000', N'legacy@example.invalid', N'Legacy director',
        N'Legacy contact', N'5550000000', 1, 1
    FROM (VALUES (@LegacyFirst, N'SC1004'), (@LegacySecond, N'SC1005'))
        AS fixture(Id, ApplicationNumber);
    EXEC sys.sp_set_session_context @key = N'FormLifecycleSyncInProgress', @value = NULL;

    INSERT dbo.Plays
    (
        Id, PlayName, StatusCode, CreatedAt, IsPublished, Slug, TheaterName,
        JuriOylamaStatus, KunyeGirisStatus, RecordType, SourceFormId, IsActive
    )
    VALUES
    (
        @LegacyPlay, N'Ambiguous legacy ' + @Suffix, 1, @Now, 1,
        'ambiguous-legacy-' + CONVERT(varchar(32), @Suffix), N'Legacy theatre ' + @Suffix,
        0, 0, 0, NULL, 1
    );
    SET @SingleScope = (SELECT @LegacyFirst AS Id FOR JSON PATH);
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @SingleScope;
    IF EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @LegacyPlay AND SourceFormId IS NOT NULL)
       OR NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE SourceFormId = @LegacyFirst AND Id <> @LegacyPlay)
       OR EXISTS (SELECT 1 FROM dbo.Plays WHERE SourceFormId = @LegacySecond)
        THROW 53297, N'Scoped legacy matching lost global uniqueness or backfilled an unrelated Form.', 1;

    /* The original no-argument maintenance API remains a deliberate full sync. */
    EXEC dbo.usp_SynchronizeFormsToPlays;
    EXEC dbo.usp_SynchronizeFormCandidates;
    IF NOT EXISTS (SELECT 1 FROM dbo.Plays WHERE SourceFormId = @LegacySecond)
       OR EXISTS (SELECT 1 FROM dbo.Plays WHERE Id = @LegacyPlay AND SourceFormId IS NOT NULL)
        THROW 53298, N'No-argument full maintenance lost backfill or global legacy ambiguity.', 1;

    ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    PRINT N'Scoped Form synchronization regression passed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'FormLifecycleSyncInProgress', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    THROW;
END CATCH;
