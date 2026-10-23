/* Disposable local database only, after the current migration: sqlcmd -I -b.
   The transaction rolls back all fixtures and audit rows. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF NOT EXISTS (SELECT 1 FROM sys.parameters
               WHERE object_id = OBJECT_ID(N'dbo.usp_SynchronizePlayDataToForms')
                 AND name = N'@PlayIdsJson')
    THROW 53750, N'Batched reverse synchronization migration is not installed.', 1;

BEGIN TRY
    EXEC dbo.usp_SynchronizePlayDataToForms @PlayIdsJson = N'[{"Id":"bad-guid"}]';
    THROW 53751, N'Reverse synchronization accepted an invalid Play scope.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52433 THROW;
END CATCH;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @A uniqueidentifier = NEWID(), @B uniqueidentifier = NEWID(), @Other uniqueidentifier = NEWID();
    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @Suffix nvarchar(32) = REPLACE(CONVERT(nvarchar(36), @A), N'-', N'');
    DECLARE @Png nvarchar(max) =
        N'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    DECLARE @OriginalActress nvarchar(max) =
        N'[ {"Name":"Source actor","Role":"Source role","ImageUrl":"source.png","Base64":"'
        + @Png + N'","LegacyExtra":{"keep":"raw-json"}} ]';
    DECLARE @OriginalStage nvarchar(max) =
        N'[ {"Name":"Stage artist","Role":"Stage role","ImportedField":"preserve"} ]';
    DECLARE @OriginalYoung nvarchar(max) = N'[{"Name":"Legacy young artist","LegacyExtra":true}]';

    INSERT dbo.Form
    (
        Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
        TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
        Phone, Email, Director, ContactName, ContactPhone, LeadActress,
        LeadActor, SupportActress, SupportActor, StageDesign, ClothesDesign,
        LightDesign, StageMusic, Choreography, YoungGenerationArtist, IsPublished, IsActive
    )
    SELECT fixture.Id, fixture.ApplicationNumber, @Now, @Now,
        fixture.PlayName + @Suffix, N'Reverse theatre ' + @Suffix,
        CONVERT(date, @Now), N'[]', N'Reverse applicant', N'Contact',
        N'5550000000', N'reverse@example.invalid', N'Source director',
        N'Reverse contact', N'5550000001', @OriginalActress,
        NULL, NULL, NULL, @OriginalStage, NULL, NULL, NULL, NULL, @OriginalYoung, 1, 1
    FROM
    (
        VALUES (@A, N'RV1001', N'Reverse first '),
               (@B, N'RV1002', N'Reverse second '),
               (@Other, N'RV1003', N'Reverse unrelated ')
    ) AS fixture(Id, ApplicationNumber, PlayName);

    DECLARE @PlayA uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @A);
    DECLARE @PlayB uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @B);
    DECLARE @PlayOther uniqueidentifier = (SELECT Id FROM dbo.Plays WHERE SourceFormId = @Other);
    IF @PlayA IS NULL OR @PlayB IS NULL OR @PlayOther IS NULL
        THROW 53752, N'Reverse synchronization fixture did not create all Plays.', 1;

    /* Stage an admin candidate that has not yet received an import slot.
       Metadata-only Play edits must not trigger slot repair or JSON rebuilds. */
    DECLARE @PendingCandidate uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'PlayToFormSyncInProgress', @value = 1;
    INSERT dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, IsPublished, IsActive, IsCurrent,
        Candidate, AwardCategoryCode, Role, RoleCode, SourceFormCandidateOrder
    )
    VALUES (@PendingCandidate, @PlayA, @Now, 1, 1, 1,
            N'Admin actor', 1004, N'Admin role', 7004, NULL);
    EXEC sys.sp_set_session_context @key = N'PlayToFormSyncInProgress', @value = NULL;

    DECLARE @UnrelatedBefore nvarchar(max) =
        (SELECT * FROM dbo.Form WHERE Id = @Other FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @UnrelatedCandidatesBefore nvarchar(max) =
        (SELECT * FROM dbo.PlayAwardCategories WHERE PlayId = @PlayOther
         ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);

    /* One batch updates two source Forms without touching any candidate JSON,
       its unknown properties/formatting, Director, or removed legacy category. */
    UPDATE dbo.Plays
    SET PlayName = PlayName + N' metadata', Phone = NULL, Email = NULL,
        ContactPersonName = N'Updated contact', ContactPersonPhone = N'5550000002'
    WHERE Id IN (@PlayA, @PlayB);
    IF (SELECT COUNT(*) FROM dbo.Form WHERE Id IN (@A, @B)
        AND RepertoireName LIKE N'% metadata' AND ContactName = N'Updated contact'
        AND ContactPhone = N'5550000002' AND Phone = N'5550000000'
        AND Email = N'reverse@example.invalid' AND Director = N'Source director') <> 2
        THROW 53753, N'Multirow Play metadata update lost a Form or fallback contact value.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.Form WHERE Id IN (@A, @B)
          AND (ISNULL(CONVERT(varbinary(max), LeadActress), 0x) <> CONVERT(varbinary(max), @OriginalActress)
            OR ISNULL(CONVERT(varbinary(max), StageDesign), 0x) <> CONVERT(varbinary(max), @OriginalStage)
            OR ISNULL(CONVERT(varbinary(max), YoungGenerationArtist), 0x) <> CONVERT(varbinary(max), @OriginalYoung)
            OR LeadActor IS NOT NULL OR SupportActress IS NOT NULL OR SupportActor IS NOT NULL)
    )
       OR EXISTS (SELECT 1 FROM dbo.PlayAwardCategories
                  WHERE Id = @PendingCandidate AND SourceFormCandidateOrder IS NOT NULL)
        THROW 53754, N'Metadata-only Play edit rebuilt source JSON or repaired candidate slots.', 1;

    DECLARE @NoOpCorrelation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @NoOpCorrelation;

    /* Statement triggers also fire for zero affected rows. Their FOR JSON
       result can be SQL NULL, which must never invoke full maintenance. */
    INSERT dbo.Form
    (
        Id, ApplicationNumber, RepertoireName, TheatreName, PremiereDate,
        Display, ApplicantName, ApplicantRole, Phone, Email, Director, IsPublished, IsActive
    )
    SELECT Id, ApplicationNumber, RepertoireName, TheatreName, PremiereDate,
           Display, ApplicantName, ApplicantRole, Phone, Email, Director, IsPublished, IsActive
    FROM dbo.Form WHERE 1 = 0;
    UPDATE dbo.Form SET Director = Director WHERE 1 = 0;
    DELETE dbo.Form WHERE 1 = 0;
    UPDATE dbo.Plays SET PlayName = PlayName WHERE 1 = 0;
    UPDATE dbo.PlayAwardCategories SET Candidate = Candidate WHERE 1 = 0;
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs WHERE CorrelationId = @NoOpCorrelation)
       OR EXISTS (SELECT 1 FROM dbo.PlayAwardCategories
                  WHERE Id = @PendingCandidate AND SourceFormCandidateOrder IS NOT NULL)
        THROW 53760, N'Zero-row DML expanded into full synchronization or persistent audit writes.', 1;

    UPDATE dbo.Plays SET PlayName = PlayName WHERE Id IN (@PlayA, @PlayB);
    UPDATE dbo.PlayAwardCategories SET Candidate = Candidate
    WHERE PlayId IN (@PlayA, @PlayB) AND AwardCategoryCode = 1003;
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs
               WHERE CorrelationId = @NoOpCorrelation AND TableName = N'Form')
        THROW 53755, N'Unchanged Play or candidate values caused source Form audit writes.', 1;

    /* Candidate changes still project both plays, preserving photo content,
       assigning missing slots, and leaving unrelated Forms/candidates alone. */
    UPDATE dbo.PlayAwardCategories
    SET Candidate = CASE PlayId WHEN @PlayA THEN N'First actor revised'
                               ELSE N'Second actor revised' END
    WHERE PlayId IN (@PlayA, @PlayB) AND AwardCategoryCode = 1003 AND IsCurrent = 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @A
                   AND JSON_VALUE(LeadActress, N'$[0].Name') = N'First actor revised')
       OR NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @B
                      AND JSON_VALUE(LeadActress, N'$[0].Name') = N'Second actor revised')
       OR EXISTS (SELECT 1 FROM dbo.Form WHERE Id IN (@A, @B)
                  AND ISNULL(JSON_VALUE(LeadActress, N'$[0].Base64'), N'') <> @Png)
       OR NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories
                      WHERE Id = @PendingCandidate AND SourceFormCandidateOrder = 1)
       OR NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @A
                      AND JSON_VALUE(LeadActor, N'$[0].Name') = N'Admin actor')
        THROW 53756, N'Batched candidate projection lost a Form, photo bytes or source slot.', 1;

    UPDATE dbo.PlayAwardCategories
    SET Candidate = CASE PlayId WHEN @PlayA THEN N'First director revised'
                               ELSE N'Second director revised' END
    WHERE PlayId IN (@PlayA, @PlayB) AND AwardCategoryCode = 1002 AND IsCurrent = 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @A AND Director = N'First director revised')
       OR NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @B AND Director = N'Second director revised')
        THROW 53757, N'Multirow director update did not project all source Forms.', 1;

    IF CONVERT(varbinary(max), @UnrelatedBefore) <>
       CONVERT(varbinary(max),
           (SELECT * FROM dbo.Form WHERE Id = @Other FOR JSON PATH, INCLUDE_NULL_VALUES))
       OR CONVERT(varbinary(max), @UnrelatedCandidatesBefore) <>
          CONVERT(varbinary(max),
              (SELECT * FROM dbo.PlayAwardCategories WHERE PlayId = @PlayOther
               ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES))
        THROW 53758, N'Batched reverse synchronization modified an unrelated source.', 1;

    /* Keep old scalar callers and new batched/empty scopes idempotent once
       the selected source has reached its canonical candidate representation. */
    DECLARE @PlayScope nvarchar(max) =
        (SELECT Id FROM dbo.Plays WHERE Id IN (@PlayA, @PlayB) FOR JSON PATH);
    DECLARE @ExplicitCorrelation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @ExplicitCorrelation;
    EXEC dbo.usp_SynchronizePlayDataToForms @PlayId = @PlayA;
    EXEC dbo.usp_SynchronizePlayDataToForms @PlayIdsJson = @PlayScope;
    EXEC dbo.usp_SynchronizePlayDataToForms @PlayIdsJson = N'[]';
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs
               WHERE CorrelationId = @ExplicitCorrelation AND TableName = N'Form')
        THROW 53759, N'An unchanged scalar/batched or empty scope rewrote a source Form.', 1;

    /* The historical no-argument entry point remains explicit full maintenance. */
    EXEC dbo.usp_SynchronizePlayDataToForms;

    ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    PRINT N'Batched reverse Form synchronization regression passed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'PlayToFormSyncInProgress', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    THROW;
END CATCH;
