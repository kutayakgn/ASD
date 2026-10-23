CREATE OR ALTER PROCEDURE [dbo].[usp_ReassignFormSeasons]
    @ChangedSeasonsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    CREATE TABLE #ChangedSeasonRanges
    (Id uniqueidentifier NOT NULL, StartDate date NOT NULL, EndDate date NOT NULL);
    IF @ChangedSeasonsJson IS NOT NULL
    BEGIN
        IF ISJSON(@ChangedSeasonsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@ChangedSeasonsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52742, N'Changed seasons must be an array.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@ChangedSeasonsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max), StartDate nvarchar(max), EndDate nvarchar(max)) AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
               OR scope.StartDate IS NULL OR scope.EndDate IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.EndDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) >= TRY_CONVERT(date, scope.EndDate, 23)
        ) THROW 52742, N'Changed season range is invalid.', 1;
        INSERT #ChangedSeasonRanges
        SELECT DISTINCT CONVERT(uniqueidentifier, Id), CONVERT(date, StartDate, 23), CONVERT(date, EndDate, 23)
        FROM OPENJSON(@ChangedSeasonsJson) WITH (Id nvarchar(36), StartDate nvarchar(10), EndDate nvarchar(10));
    END;

    CREATE TABLE #SeasonForms (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @ChangedSeasonsJson IS NULL
        INSERT #SeasonForms SELECT Id FROM dbo.Form;
    ELSE
        INSERT #SeasonForms
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord
            ON formRecord.CreatedDate >= CONVERT(datetime, changed.StartDate)
           AND formRecord.CreatedDate < CONVERT(datetime, changed.EndDate)
        UNION
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord ON formRecord.SeasonId = changed.Id;

    BEGIN TRY
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;

        UPDATE formRecord
        SET SeasonId = selectedSeason.Id
        FROM dbo.Form AS formRecord
        INNER JOIN #SeasonForms AS affected ON affected.Id = formRecord.Id
        OUTER APPLY
        (
            SELECT TOP (1) season.Id
            FROM dbo.Seasons AS season
            WHERE season.IsPublished = 1
              AND formRecord.CreatedDate IS NOT NULL
              AND formRecord.CreatedDate >= CONVERT(datetime, season.SeasonStartDate)
              AND formRecord.CreatedDate < CONVERT(datetime, season.SeasonEndDate)
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
