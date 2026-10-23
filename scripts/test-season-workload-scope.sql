/* Disposable database only; all fixtures and audit rows roll back. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @First uniqueidentifier = NEWID(), @Middle uniqueidentifier = NEWID(), @Last uniqueidentifier = NEWID();
    INSERT dbo.Seasons
        (Id, SeasonStartDate, SeasonEndDate, KunyeRegistrationStartDate, KunyeRegistrationEndDate,
         VotingStartDate, VotingEndDate, PlayCount, ActivePlayCount, VoteCount, IsPublished)
    VALUES
        (@First, '20900101', '20901231', '20900101', '20900601', '20900601', '20901231', 0, 0, 0, 1),
        (@Middle, '20910101', '20911231', '20910101', '20910601', '20910601', '20911231', 0, 0, 0, 1),
        (@Last, '20920101', '20921231', '20920101', '20920601', '20920601', '20921231', 0, 0, 0, 1);
    DECLARE @Form1 uniqueidentifier = NEWID(), @Form2 uniqueidentifier = NEWID(), @Form3 uniqueidentifier = NEWID();
    DECLARE @Suffix nvarchar(36) = CONVERT(nvarchar(36), @Form1);
    INSERT dbo.Form
        (Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName, TheatreName, PremiereDate,
         Display, ApplicantName, ApplicantRole, Phone, Email, Director, ContactName, ContactPhone, IsPublished, IsActive)
    SELECT fixture.Id, fixture.Number, fixture.CreatedDate, fixture.CreatedDate, N'Season scope ' + @Suffix + fixture.Number,
        N'Scope theatre', CONVERT(date, fixture.CreatedDate), N'[]', N'Applicant', N'Contact', N'5550000000',
        N'season@example.invalid', N'Director', N'Contact', N'5550000000', 1, 1
    FROM (VALUES (@Form1, N'SE1001', CONVERT(datetime, '20900701')),
                 (@Form2, N'SE1002', CONVERT(datetime, '20910701')),
                 (@Form3, N'SE1003', CONVERT(datetime, '20920701'))) fixture(Id, Number, CreatedDate);
    IF EXISTS (SELECT 1 FROM dbo.Form WHERE (Id = @Form1 AND SeasonId <> @First)
        OR (Id = @Form2 AND SeasonId <> @Middle) OR (Id = @Form3 AND SeasonId <> @Last))
        THROW 53400, N'Initial season assignment failed.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Seasons WHERE Id IN (@First, @Middle, @Last) AND PlayCount <> 1)
        THROW 53401, N'Initial scoped play statistics failed.', 1;

    /* A multi-row statement with distant dates must not repair/touch the middle season. */
    UPDATE dbo.Seasons SET PlayCount = 987 WHERE Id = @Middle;
    UPDATE dbo.Plays SET StatusCode = CASE WHEN StatusCode = 1 THEN 2 ELSE 1 END
        WHERE SourceFormId IN (@Form1, @Form3);
    IF NOT EXISTS (SELECT 1 FROM dbo.Seasons WHERE Id = @Middle AND PlayCount = 987)
        THROW 53402, N'Play trigger recounted an unrelated intervening season.', 1;
    DECLARE @Scope nvarchar(max) = N'[{"Id":"' + CONVERT(nvarchar(36), @First) + N'"}]';
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @Scope;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = N'[]';
    IF NOT EXISTS (SELECT 1 FROM dbo.Seasons WHERE Id = @Middle AND PlayCount = 987)
        THROW 53403, N'Explicit or empty statistic scope touched unrelated data.', 1;

    /* Leave an unrelated historical assignment deliberately inconsistent. A
       boundary edit must only examine its old/new date ranges or assignments. */
    EXEC sys.sp_set_session_context @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;
    UPDATE dbo.Form SET SeasonId = @Last WHERE Id = @Form2;
    EXEC sys.sp_set_session_context @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    UPDATE dbo.Seasons SET SeasonEndDate = '20901230', VotingEndDate = '20901230' WHERE Id = @First;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Form2 AND SeasonId = @Last)
        THROW 53404, N'Season edit repaired an unrelated historical Form.', 1;
    EXEC dbo.usp_ReassignFormSeasons @ChangedSeasonsJson = N'[]';
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Form2 AND SeasonId = @Last)
        THROW 53405, N'Empty season assignment scope was not a no-op.', 1;
    DELETE dbo.Seasons WHERE Id = @First;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Form1 AND SeasonId IS NULL)
        THROW 53408, N'Season soft-delete did not remove its own assignment.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Form2 AND SeasonId = @Last)
        THROW 53409, N'Season soft-delete repaired an unrelated assignment.', 1;
    EXEC dbo.usp_ReassignFormSeasons;
    IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Form2 AND SeasonId = @Middle)
        THROW 53406, N'Explicit full maintenance did not repair legacy assignment.', 1;
    EXEC dbo.usp_RefreshSeasonStatistics;
    IF NOT EXISTS (SELECT 1 FROM dbo.Seasons WHERE Id = @Middle AND PlayCount = 1)
        THROW 53407, N'Full statistic maintenance did not repair counts.', 1;
    ROLLBACK TRANSACTION;
    PRINT N'Season exact scope, distant multi-row dates, empty scope and full repair passed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    THROW;
END CATCH;
