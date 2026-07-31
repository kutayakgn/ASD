SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    Deployment order:
    1. This script
    2. create-seasons-and-statistics.sql
    3. create-rankings-projection.sql
    4. create-admin-audit-logging.sql

    The migration never deletes a row. Legacy Form identifiers are converted to
    deterministic GUIDs in place and related records use soft-delete snapshots.
*/

IF OBJECT_ID(N'dbo.Form', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Seasons', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryVotes', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryGameTicketFees', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryAssignedPlays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Blacklist', N'U') IS NULL
BEGIN
    THROW 52400, N'Form yaşam döngüsü için gereken tablolar bulunamadı.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Convert the legacy Form key and season key without rebuilding the table. */
    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Form')
          AND name = N'Id'
          AND TYPE_NAME(user_type_id) = N'int'
    )
    BEGIN
        IF COL_LENGTH(N'dbo.Form', N'GuidId') IS NULL
            ALTER TABLE dbo.Form ADD GuidId uniqueidentifier NULL;

        EXEC sys.sp_executesql N'
            UPDATE dbo.Form
            SET GuidId = CONVERT
            (
                uniqueidentifier,
                CONCAT
                (
                    N''f0000000-0000-0000-0000-'',
                    RIGHT(N''000000000000'' + CONVERT(nvarchar(12), Id), 12)
                )
            )
            WHERE GuidId IS NULL;';

        DECLARE @HasDuplicateFormGuid bit = 0;
        EXEC sys.sp_executesql
            N'IF EXISTS
              (
                  SELECT GuidId FROM dbo.Form
                  GROUP BY GuidId HAVING COUNT_BIG(*) > 1
              ) SET @HasDuplicate = 1;',
            N'@HasDuplicate bit OUTPUT',
            @HasDuplicate = @HasDuplicateFormGuid OUTPUT;

        IF @HasDuplicateFormGuid = 1
            THROW 52401, N'Form GUID dönüşümünde yinelenen kimlik oluştu.', 1;

        DECLARE @FormPrimaryKey sysname;
        SELECT @FormPrimaryKey = constraintInfo.name
        FROM sys.key_constraints AS constraintInfo
        WHERE constraintInfo.parent_object_id = OBJECT_ID(N'dbo.Form')
          AND constraintInfo.type = N'PK';

        IF @FormPrimaryKey IS NOT NULL
        BEGIN
            DECLARE @DropFormPrimaryKeySql nvarchar(max);
            SET @DropFormPrimaryKeySql =
                N'ALTER TABLE dbo.Form DROP CONSTRAINT ' +
                QUOTENAME(@FormPrimaryKey) + N';';
            EXEC sys.sp_executesql @DropFormPrimaryKeySql;
        END;

        ALTER TABLE dbo.Form DROP COLUMN Id;
        EXEC sys.sp_rename N'dbo.Form.GuidId', N'Id', N'COLUMN';
        EXEC sys.sp_executesql N'ALTER TABLE dbo.Form ALTER COLUMN Id uniqueidentifier NOT NULL;';
        ALTER TABLE dbo.Form ADD CONSTRAINT PK_Form PRIMARY KEY CLUSTERED (Id);
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.Form')
          AND name = N'SeasonId'
          AND TYPE_NAME(user_type_id) = N'int'
    )
    BEGIN
        IF COL_LENGTH(N'dbo.Form', N'GuidSeasonId') IS NULL
            ALTER TABLE dbo.Form ADD GuidSeasonId uniqueidentifier NULL;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Form AS formRecord
            WHERE formRecord.CreatedDate IS NULL
               OR
               (
                   SELECT COUNT_BIG(*)
                   FROM dbo.Seasons AS season
                   WHERE season.IsPublished = 1
                     AND CAST(formRecord.CreatedDate AS date) >= season.SeasonStartDate
                     AND CAST(formRecord.CreatedDate AS date) < season.SeasonEndDate
               ) = 0
        )
            THROW 52402, N'Her Form.CreatedDate en az bir yayımlanmış sezonla eşleşmelidir.', 1;

        EXEC sys.sp_executesql N'
            UPDATE formRecord
            SET GuidSeasonId = selectedSeason.Id
            FROM dbo.Form AS formRecord
            CROSS APPLY
            (
                SELECT TOP (1) season.Id
                FROM dbo.Seasons AS season
                WHERE season.IsPublished = 1
                  AND CAST(formRecord.CreatedDate AS date) >= season.SeasonStartDate
                  AND CAST(formRecord.CreatedDate AS date) < season.SeasonEndDate
                ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
            ) AS selectedSeason;';

        ALTER TABLE dbo.Form DROP COLUMN SeasonId;
        EXEC sys.sp_rename N'dbo.Form.GuidSeasonId', N'SeasonId', N'COLUMN';
        EXEC sys.sp_executesql N'ALTER TABLE dbo.Form ALTER COLUMN SeasonId uniqueidentifier NOT NULL;';
    END;

    IF COL_LENGTH(N'dbo.Form', N'IsActive') IS NULL
        ALTER TABLE dbo.Form ADD IsActive bit NULL;

    IF COL_LENGTH(N'dbo.Form', N'Active') IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql N'
            UPDATE dbo.Form
            SET IsActive = CASE
                WHEN IsPublished = 1
                 AND COALESCE(Deleted, 0) = 0
                 AND Active = 1 THEN 1
                ELSE 0
            END
            WHERE IsActive IS NULL;';

        ALTER TABLE dbo.Form DROP COLUMN Active;
    END;

    EXEC sys.sp_executesql N'UPDATE dbo.Form SET IsActive = 1 WHERE IsActive IS NULL;';
    EXEC sys.sp_executesql N'ALTER TABLE dbo.Form ALTER COLUMN IsActive bit NOT NULL;';

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS defaultInfo
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.object_id = defaultInfo.parent_object_id
           AND columnInfo.column_id = defaultInfo.parent_column_id
        WHERE defaultInfo.parent_object_id = OBJECT_ID(N'dbo.Form')
          AND columnInfo.name = N'IsActive'
    )
        ALTER TABLE dbo.Form
            ADD CONSTRAINT DF_Form_IsActive DEFAULT (1) FOR IsActive;

    IF COL_LENGTH(N'dbo.Form', N'Deleted') IS NOT NULL
        ALTER TABLE dbo.Form DROP COLUMN Deleted;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS defaultInfo
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.object_id = defaultInfo.parent_object_id
           AND columnInfo.column_id = defaultInfo.parent_column_id
        WHERE defaultInfo.parent_object_id = OBJECT_ID(N'dbo.Form')
          AND columnInfo.name = N'Id'
    )
        ALTER TABLE dbo.Form
            ADD CONSTRAINT DF_Form_Id DEFAULT (NEWSEQUENTIALID()) FOR Id;

    IF OBJECT_ID(N'dbo.FK_Form_Seasons', N'F') IS NULL
        ALTER TABLE dbo.Form WITH CHECK
            ADD CONSTRAINT FK_Form_Seasons FOREIGN KEY (SeasonId)
                REFERENCES dbo.Seasons (Id)
                ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS defaultInfo
        INNER JOIN sys.columns AS columnInfo
            ON columnInfo.object_id = defaultInfo.parent_object_id
           AND columnInfo.column_id = defaultInfo.parent_column_id
        WHERE defaultInfo.parent_object_id = OBJECT_ID(N'dbo.Form')
          AND columnInfo.name = N'SeasonId'
    )
        ALTER TABLE dbo.Form
            ADD CONSTRAINT DF_Form_SeasonId
                DEFAULT ('00000000-0000-0000-0000-000000000000') FOR SeasonId;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Form')
          AND name = N'UX_Form_ApplicationNumber_Published'
    )
        CREATE UNIQUE INDEX UX_Form_ApplicationNumber_Published
            ON dbo.Form (ApplicationNumber)
            WHERE IsPublished = 1;

    /* Preserve Turkish text supplied by the Kunye form. */
    ALTER TABLE dbo.Plays ALTER COLUMN TheaterName nvarchar(255) NOT NULL;
    ALTER TABLE dbo.Plays ALTER COLUMN Phone nvarchar(255) NULL;
    ALTER TABLE dbo.Plays ALTER COLUMN ContactPersonName nvarchar(255) NULL;
    ALTER TABLE dbo.Plays ALTER COLUMN ContactPersonPhone nvarchar(255) NULL;
    ALTER TABLE dbo.Plays ALTER COLUMN Address nvarchar(255) NULL;
    ALTER TABLE dbo.Plays ALTER COLUMN Email nvarchar(255) NULL;

    IF COL_LENGTH(N'dbo.Plays', N'SourceFormId') IS NULL
        ALTER TABLE dbo.Plays ADD SourceFormId uniqueidentifier NULL;

    IF COL_LENGTH(N'dbo.Plays', N'IsActive') IS NULL
        ALTER TABLE dbo.Plays
            ADD IsActive bit NOT NULL
                CONSTRAINT DF_Plays_IsActive DEFAULT (1) WITH VALUES;

    IF OBJECT_ID(N'dbo.FK_Plays_Form_SourceFormId', N'F') IS NULL
        EXEC sys.sp_executesql N'
            ALTER TABLE dbo.Plays WITH CHECK
                ADD CONSTRAINT FK_Plays_Form_SourceFormId FOREIGN KEY (SourceFormId)
                    REFERENCES dbo.Form (Id)
                    ON UPDATE NO ACTION ON DELETE NO ACTION;';

    IF OBJECT_ID(N'dbo.CK_Plays_SourceFormRequiresKunye', N'C') IS NULL
        EXEC sys.sp_executesql N'
            ALTER TABLE dbo.Plays WITH CHECK
                ADD CONSTRAINT CK_Plays_SourceFormRequiresKunye
                    CHECK (SourceFormId IS NULL OR RecordType = 0);';

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.Plays')
          AND name = N'UX_Plays_SourceFormId'
    )
        EXEC sys.sp_executesql N'
            CREATE UNIQUE INDEX UX_Plays_SourceFormId
                ON dbo.Plays (SourceFormId)
                WHERE SourceFormId IS NOT NULL;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

IF OBJECT_ID(N'dbo.FormLifecycleStates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FormLifecycleStates
    (
        Id uniqueidentifier NOT NULL
            CONSTRAINT DF_FormLifecycleStates_Id DEFAULT (NEWSEQUENTIALID()),
        FormId uniqueidentifier NOT NULL,
        EntityName nvarchar(64) NOT NULL,
        EntityId uniqueidentifier NOT NULL,
        WasPublished bit NOT NULL,
        WasActive bit NULL,
        WasJuriOylamaStatus bit NULL,
        WasKunyeGirisStatus bit NULL,
        WasStatusCode int NULL,
        DeactivatedAt datetime2(7) NOT NULL,
        RestoredAt datetime2(7) NULL,
        IsPublished bit NOT NULL
            CONSTRAINT DF_FormLifecycleStates_IsPublished DEFAULT (1),
        CONSTRAINT PK_FormLifecycleStates PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_FormLifecycleStates_Form FOREIGN KEY (FormId)
            REFERENCES dbo.Form (Id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );

    CREATE UNIQUE INDEX UX_FormLifecycleStates_OpenEntity
        ON dbo.FormLifecycleStates (FormId, EntityName, EntityId)
        WHERE IsPublished = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SynchronizeFormsToPlays
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    DECLARE @LockResult int;
    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @LockResult < 0
        THROW 52403, N'Form senkronizasyon kilidi alınamadı.', 1;

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* Link a unique exact legacy match before creating a new play. */
        ;WITH ExactMatches AS
        (
            SELECT
                formRecord.Id AS FormId,
                play.Id AS PlayId,
                COUNT_BIG(*) OVER (PARTITION BY formRecord.Id) AS PlayMatchCount,
                COUNT_BIG(*) OVER (PARTITION BY play.Id) AS FormMatchCount
            FROM dbo.Form AS formRecord
            INNER JOIN dbo.Plays AS play
                ON play.RecordType = 0
               AND play.SourceFormId IS NULL
               AND LOWER(LTRIM(RTRIM(play.PlayName))) =
                   LOWER(LTRIM(RTRIM(formRecord.RepertoireName)))
               AND LOWER(LTRIM(RTRIM(play.TheaterName))) =
                   LOWER(LTRIM(RTRIM(formRecord.TheatreName)))
        )
        UPDATE play
        SET SourceFormId = exact.FormId,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN ExactMatches AS exact ON exact.PlayId = play.Id
        WHERE exact.PlayMatchCount = 1
          AND exact.FormMatchCount = 1;

        INSERT INTO dbo.Plays
        (
            Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt,
            UpdatedBy, IsPublished, Slug, TheaterName, Phone,
            ContactPersonName, ContactPersonPhone, Address, Email,
            JuriOylamaStatus, KunyeGirisStatus, RecordType,
            SourceFormId, IsActive
        )
        SELECT
            NEWID(),
            formRecord.RepertoireName,
            1,
            formRecord.CreatedDate,
            NULL,
            formRecord.UpdatedDate,
            NULL,
            1,
            LOWER
            (
                CONCAT
                (
                    'kunye-',
                    REPLACE(formRecord.ApplicationNumber, ' ', '-'),
                    '-',
                    LEFT(CONVERT(varchar(36), formRecord.Id), 8)
                )
            ),
            formRecord.TheatreName,
            formRecord.Phone,
            COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            NULL,
            formRecord.Email,
            1,
            1,
            0,
            formRecord.Id,
            1
        FROM dbo.Form AS formRecord
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Plays AS play
              WHERE play.SourceFormId = formRecord.Id
          );

        UPDATE play
        SET
            PlayName = formRecord.RepertoireName,
            CreatedAt = formRecord.CreatedDate,
            UpdatedAt = COALESCE(formRecord.UpdatedDate, @Now),
            TheaterName = formRecord.TheatreName,
            Phone = formRecord.Phone,
            ContactPersonName =
                COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            ContactPersonPhone =
                COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            Email = formRecord.Email
        FROM dbo.Plays AS play
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        WHERE play.RecordType = 0
          AND
          (
              play.PlayName <> formRecord.RepertoireName
              OR play.CreatedAt <> formRecord.CreatedDate
              OR play.TheaterName <> formRecord.TheatreName
              OR COALESCE(play.Phone, N'') <> COALESCE(formRecord.Phone, N'')
              OR COALESCE(play.ContactPersonName, N'') <>
                    COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName)
              OR COALESCE(play.ContactPersonPhone, N'') <>
                    COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone)
              OR COALESCE(play.Email, N'') <> COALESCE(formRecord.Email, N'')
          );

        CREATE TABLE #DeactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #DeactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        WHERE play.IsActive = 1
          AND (formRecord.IsPublished = 0 OR formRecord.IsActive = 0);

        INSERT INTO dbo.FormLifecycleStates
        (
            Id, FormId, EntityName, EntityId, WasPublished, WasActive,
            WasJuriOylamaStatus, WasKunyeGirisStatus, WasStatusCode,
            DeactivatedAt, RestoredAt, IsPublished
        )
        SELECT
            NEWID(), affected.FormId, N'Play', play.Id,
            play.IsPublished, play.IsActive,
            play.JuriOylamaStatus, play.KunyeGirisStatus, play.StatusCode,
            @Now, NULL, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Plays AS play ON play.Id = affected.PlayId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.FormLifecycleStates AS state
            WHERE state.FormId = affected.FormId
              AND state.EntityName = N'Play'
              AND state.EntityId = play.Id
              AND state.IsPublished = 1
        );

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'PlayAwardCategory', candidate.Id,
               candidate.IsPublished, candidate.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        WHERE candidate.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryVote', vote.Id,
               vote.IsPublished, vote.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        INNER JOIN dbo.JuryVotes AS vote
            ON vote.PlayAwardCategoryId = candidate.Id
        WHERE vote.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryGameTicketFee', ticket.Id,
               ticket.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryGameTicketFees AS ticket
            ON ticket.PlayId = affected.PlayId
        WHERE ticket.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryAssignedPlay', assignment.Id,
               assignment.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryAssignedPlays AS assignment
            ON assignment.PlayId = affected.PlayId
        WHERE assignment.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'Blacklist', blacklist.Id,
               blacklist.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Blacklist AS blacklist
            ON blacklist.PlayId = affected.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE vote
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE vote.IsPublished = 1 OR vote.IsActive = 1;

        UPDATE candidate
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE candidate.IsPublished = 1 OR candidate.IsActive = 1;

        UPDATE ticket
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = ticket.PlayId
        WHERE ticket.IsPublished = 1;

        UPDATE assignment
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = assignment.PlayId
        WHERE assignment.IsPublished = 1;

        UPDATE blacklist
        SET IsPublished = 0
        FROM dbo.Blacklist AS blacklist
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = blacklist.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE play
        SET IsActive = 0,
            JuriOylamaStatus = 0,
            KunyeGirisStatus = 0,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #DeactivateForms AS affected ON affected.PlayId = play.Id;

        CREATE TABLE #ReactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #ReactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND play.IsActive = 0
          AND EXISTS
          (
              SELECT 1 FROM dbo.FormLifecycleStates AS state
              WHERE state.FormId = formRecord.Id
                AND state.EntityName = N'Play'
                AND state.EntityId = play.Id
                AND state.IsPublished = 1
          );

        UPDATE play
        SET IsActive = 1,
            JuriOylamaStatus = state.WasJuriOylamaStatus,
            KunyeGirisStatus = state.WasKunyeGirisStatus,
            StatusCode = state.WasStatusCode,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #ReactivateForms AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.FormId = affected.FormId
           AND state.EntityName = N'Play'
           AND state.EntityId = play.Id
           AND state.IsPublished = 1;

        UPDATE candidate
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'PlayAwardCategory'
           AND state.EntityId = candidate.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE vote
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryVote'
           AND state.EntityId = vote.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE ticket
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryGameTicketFee'
           AND state.EntityId = ticket.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE assignment
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryAssignedPlay'
           AND state.EntityId = assignment.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE blacklist
        SET IsPublished = state.WasPublished
        FROM dbo.Blacklist AS blacklist
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'Blacklist'
           AND state.EntityId = blacklist.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE state
        SET IsPublished = 0, RestoredAt = @Now
        FROM dbo.FormLifecycleStates AS state
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        WHERE state.IsPublished = 1;

        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
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

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        LEFT JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE previous.Id IS NOT NULL
          AND previous.Id <> changed.Id
    )
        THROW 52404, N'Form.Id oluşturulduktan sonra değiştirilemez.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        WHERE changed.CreatedDate IS NULL
           OR
           (
               SELECT COUNT_BIG(*)
               FROM dbo.Seasons AS season
               WHERE season.IsPublished = 1
                 AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
                 AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
           ) = 0
    )
        THROW 52405, N'Form.CreatedDate en az bir yayımlanmış sezonla eşleşmelidir.', 1;

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
    CROSS APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
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
    CROSS APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
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

CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    EXEC dbo.usp_SynchronizeFormsToPlays;
END;
GO

/* Lifecycle sync restores votes explicitly from snapshots. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET vote.IsActive = candidate.IsActive,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsActive <> candidate.IsActive
          AND vote.IsPublished = 1
          AND vote.IsActive <> candidate.IsActive;
    END;

    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR vote.IsActive <> CASE
                    WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END
          );
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    ;WITH AffectedGroups AS
    (
        SELECT PlayId, AwardCategoryCode, RoleCode FROM inserted
        UNION
        SELECT PlayId, AwardCategoryCode, RoleCode FROM deleted
    ),
    RankedVotes AS
    (
        SELECT vote.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY vote.JuryId, candidate.PlayId,
                       candidate.AwardCategoryCode, candidate.RoleCode
                   ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                       CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
               ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN AffectedGroups AS affected
            ON affected.PlayId = candidate.PlayId
           AND affected.AwardCategoryCode = candidate.AwardCategoryCode
           AND affected.RoleCode = candidate.RoleCode
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO

/* Reject new visible relationships while their source Form is inactive. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockInactiveSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52410, N'Pasif Form kaynağına yayımlanmış aday/kategori eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_BlockInactiveSourceForm
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changed.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52411, N'Pasif Form kaynağı için yayımlanmış jüri oyu eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_BlockInactiveSourceForm
ON dbo.JuryGameTicketFees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52412, N'Pasif Form kaynağı için yayımlanmış bilet ücreti eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_BlockInactiveSourceForm
ON dbo.JuryAssignedPlays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52413, N'Pasif Form kaynağı için yayımlanmış jüri ataması eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_BlockInactiveSourceForm
ON dbo.Blacklist
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52414, N'Pasif Form kaynağı için yayımlanmış blacklist kaydı eklenemez.', 1;
END;
GO

EXEC dbo.usp_SynchronizeFormsToPlays;
GO

SELECT
    COUNT_BIG(*) AS FormCount,
    SUM(CASE WHEN IsPublished = 1 AND IsActive = 1 THEN 1 ELSE 0 END) AS ActiveFormCount
FROM dbo.Form;

SELECT
    COUNT_BIG(*) AS FormSourcedPlayCount,
    SUM(CASE WHEN IsPublished = 1 AND IsActive = 1 THEN 1 ELSE 0 END) AS ActivePlayCount
FROM dbo.Plays
WHERE SourceFormId IS NOT NULL;
GO
