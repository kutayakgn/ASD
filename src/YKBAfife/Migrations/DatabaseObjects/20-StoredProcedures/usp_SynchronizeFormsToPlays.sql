CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormsToPlays]
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
            0,
            0,
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

        EXEC dbo.usp_SynchronizeFormCandidates;

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
