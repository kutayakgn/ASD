/* Disposable, fully migrated local database only (sqlcmd -I -b).
   Every fixture, deliberately altered cache value and audit row is rolled back.
   Tests do not disable triggers or change production data. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.usp_RefreshRankings') AND name = N'@CandidateIdsJson')
    THROW 53340, N'Incremental ranking migration is not installed.', 1;

/* Validation precedes the fixture transaction because XACT_ABORT can doom it. */
DECLARE @BadScopes TABLE (Categories nvarchar(max) NULL, Candidates nvarchar(max) NULL);
INSERT @BadScopes VALUES
    (N'{}', NULL), (N'not-json', NULL), (N'[1]', NULL),
    (N'[{"CategoryCode":"invalid"}]', NULL),
    (NULL, N'[]'), (N'[]', N'{}'), (N'[]', N'["invalid"]'),
    (N'[]', N'[{"Id":null}]'),
    (N'[]', N'[{"Id":"00000000-0000-0000-0000-000000000000-extra"}]');
DECLARE @BadCategories nvarchar(max), @BadCandidates nvarchar(max);
DECLARE validation_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT Categories, Candidates FROM @BadScopes;
OPEN validation_cursor;
FETCH NEXT FROM validation_cursor INTO @BadCategories, @BadCandidates;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @BadCategories, @CandidateIdsJson = @BadCandidates;
        THROW 53341, N'Invalid ranking scope was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 52740 THROW;
    END CATCH;
    FETCH NEXT FROM validation_cursor INTO @BadCategories, @BadCandidates;
END;
CLOSE validation_cursor;
DEALLOCATE validation_cursor;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @PlayA uniqueidentifier = NEWID(), @PlayB uniqueidentifier = NEWID(), @PlayC uniqueidentifier = NEWID();
    DECLARE @A uniqueidentifier = NEWID(), @B uniqueidentifier = NEWID(), @C uniqueidentifier = NEWID(),
            @D uniqueidentifier = NEWID(), @Missing uniqueidentifier = NEWID();
    DECLARE @Suffix nvarchar(32) = REPLACE(CONVERT(nvarchar(36), @PlayA), N'-', N'');
    DECLARE @Juries TABLE (Position int NOT NULL PRIMARY KEY, Id uniqueidentifier NOT NULL);
    INSERT @Juries VALUES (1, NEWID()), (2, NEWID()), (3, NEWID()), (4, NEWID()), (5, NEWID());

    INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, IsPublished, RoleCode, IsActive, IsJuryPresident)
    SELECT Id, N'Workload', N'Jury', N'perf' + LEFT(@Suffix, 20) + CONVERT(nvarchar(1), Position),
           N'fixture-not-a-password', N'perf-' + @Suffix + CONVERT(nvarchar(1), Position) + N'@example.invalid', 1, 2, 1, 0
    FROM @Juries;

    INSERT dbo.Plays
        (Id, PlayName, TheaterName, Slug, StatusCode, CreatedAt, IsPublished, IsActive, JuriOylamaStatus, KunyeGirisStatus, RecordType)
    SELECT fixture.Id, N'Workload ' + fixture.Name + @Suffix, N'Workload theatre',
           CONVERT(varchar(255), N'workload-' + fixture.Name + @Suffix), 1, @Now, 1, 1, 1, 0, 0
    FROM (VALUES (@PlayA, N'a'), (@PlayB, N'b'), (@PlayC, N'c')) AS fixture(Id, Name);

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, IsActive, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
    VALUES (@A, @PlayA, @Now, 1, 1, N'Workload A', 1003, 1, N'Lead', 1),
           (@B, @PlayB, @Now, 1, 1, N'Workload B', 1003, 1, N'Lead', 1),
           (@C, @PlayC, @Now, 1, 1, N'Workload C', 1004, 1, N'Lead', 1),
           (@D, @PlayC, @Now, 1, 1, N'Workload without votes', 1003, 1, N'Support', 2);

    INSERT dbo.JuryVotes (Id, PlayAwardCategoryId, CreatedAt, IsPublished, IsActive, Score, JuryId)
    SELECT NEWID(), candidate.Id, @Now, 1, 1,
           CASE WHEN candidate.Id = @A THEN CASE jury.Position WHEN 1 THEN 1 WHEN 2 THEN 3 WHEN 3 THEN 3 ELSE 9 END
                WHEN candidate.Id = @B THEN 3 ELSE 6 END,
           jury.Id
    FROM (VALUES (@A), (@B), (@C)) AS candidate(Id) CROSS JOIN @Juries AS jury;

    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @A AND NumberOfActiveVote = 5
        AND ArithmeticMean = 5 AND TrimmedMean = 5 AND ArithmeticVariance = 14 AND ConfidenceValue = 1)
        THROW 53342, N'Vote averages, trimmed ties or sample variance changed.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @D AND NumberOfActiveVote = 0
        AND ArithmeticMean IS NULL AND TrimmedMean IS NULL AND ArithmeticRank IS NULL AND ConfidenceValue IS NULL)
        THROW 53343, N'Zero-vote/null ranking semantics changed.', 1;

    /* Deliberately distinguish cached statistics from raw votes. A scoped
       refresh must reuse the unchanged peer, and never touch another category. */
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = 1;
    UPDATE dbo.Rankings SET ArithmeticMean = 9.5 WHERE PlayAwardCategoryId = @B;
    UPDATE dbo.Rankings SET ArithmeticMean = 9.25 WHERE PlayAwardCategoryId = @C;
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = NULL;
    DECLARE @UnrelatedBefore nvarchar(max) =
        (SELECT * FROM dbo.Rankings WHERE PlayAwardCategoryId = @C FOR JSON PATH, INCLUDE_NULL_VALUES);
    /* Empty category payloads, including a removed candidate with no current
       category row, remain scoped rather than falling back to full repair. */
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = N'[]', @CandidateIdsJson = N'[]';
    DECLARE @RemovedCandidateId uniqueidentifier = NEWID();
    DECLARE @RemovedCandidates nvarchar(max) = COALESCE((SELECT @RemovedCandidateId AS Id FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = N'[]', @CandidateIdsJson = @RemovedCandidates;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @C AND ArithmeticMean = 9.25)
        THROW 53352, N'Empty category scope unexpectedly performed a full ranking rebuild.', 1;
    DECLARE @Correlation uniqueidentifier = NEWID();
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = @Correlation;

    UPDATE dbo.JuryVotes SET Score = 6
    WHERE PlayAwardCategoryId = @A AND JuryId = (SELECT Id FROM @Juries WHERE Position = 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings AS peer JOIN dbo.Rankings AS dirty ON dirty.PlayAwardCategoryId = @A
        WHERE peer.PlayAwardCategoryId = @B AND peer.ArithmeticMean = 9.5 AND peer.ArithmeticRank < dirty.ArithmeticRank)
        THROW 53344, N'Unchanged category peer votes were reaggregated instead of reusing cached metrics.', 1;
    IF CONVERT(varbinary(max), @UnrelatedBefore) <>
       CONVERT(varbinary(max), (SELECT * FROM dbo.Rankings WHERE PlayAwardCategoryId = @C FOR JSON PATH, INCLUDE_NULL_VALUES))
        THROW 53345, N'Unrelated category ranking was changed by a scoped vote refresh.', 1;
    IF EXISTS (SELECT 1 FROM dbo.AdminLogs WHERE CorrelationId = @Correlation AND TableName = N'Rankings'
        AND (OldValues LIKE N'%' + CONVERT(nvarchar(36), @C) + N'%' OR NewValues LIKE N'%' + CONVERT(nvarchar(36), @C) + N'%'))
        THROW 53346, N'Unrelated category was included in ranking audit work.', 1;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    EXEC dbo.usp_RefreshRankings; /* Restore the deliberately altered caches. */

    /* An eligible missing cache row is healed even when it is not dirty. */
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = 1;
    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, IsActive, Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode)
    VALUES (@Missing, @PlayB, @Now, 1, 1, N'Workload missing cache', 1003, 1, N'Extra', 2);
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = NULL;
    DECLARE @Categories nvarchar(max) = N'[{"CategoryCode":1003}]';
    DECLARE @Candidates nvarchar(max) = (SELECT @A AS Id FOR JSON PATH);
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @Categories, @CandidateIdsJson = @Candidates;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @Missing AND IsPublished = 1 AND NumberOfActiveVote = 0)
        THROW 53347, N'Missing eligible ranking cache was not healed.', 1;

    /* Multirow votes, category moves and eligibility changes must agree with
       the full reference rebuild while retaining existing ranking identities. */
    UPDATE dbo.JuryVotes SET Score = 9
    WHERE PlayAwardCategoryId IN (@A, @B) AND JuryId = (SELECT Id FROM @Juries WHERE Position = 2);
    UPDATE dbo.PlayAwardCategories SET AwardCategoryCode = 1004 WHERE Id = @B;
    UPDATE dbo.PlayAwardCategories SET IsCurrent = 0 WHERE Id = @D;
    IF EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @D AND IsPublished = 1)
        THROW 53348, N'Retired candidate ranking remained published.', 1;
    UPDATE dbo.Plays SET IsActive = 0 WHERE Id = @PlayA;
    IF EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @A AND IsPublished = 1)
        THROW 53349, N'Play IsActive toggle did not retire its ranking.', 1;
    UPDATE dbo.Plays SET IsActive = 1 WHERE Id = @PlayA;
    IF NOT EXISTS (SELECT 1 FROM dbo.Rankings WHERE PlayAwardCategoryId = @A AND IsPublished = 1 AND NumberOfActiveVote = 5)
        THROW 53350, N'Play reactivation did not restore its ranking statistics.', 1;

    DECLARE @Incremental nvarchar(max) =
        (SELECT * FROM dbo.Rankings ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.usp_RefreshRankings;
    DECLARE @Reference nvarchar(max) =
        (SELECT * FROM dbo.Rankings ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES);
    IF CONVERT(varbinary(max), @Incremental) <> CONVERT(varbinary(max), @Reference)
        THROW 53351, N'Incremental ranking metrics/ranks/identities differ from a full rebuild.', 1;

    ROLLBACK TRANSACTION;
    PRINT N'PASS: dirty-candidate vote aggregation, category-only reranking, missing-cache repair, lifecycle and full-rebuild parity.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'AdminCorrelationId', @value = NULL;
    THROW;
END CATCH;
