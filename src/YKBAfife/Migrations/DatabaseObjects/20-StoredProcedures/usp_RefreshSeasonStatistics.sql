CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshSeasonStatistics]
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL,
    @SeasonIdsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;
    CREATE TABLE #StatisticSeasons (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @SeasonIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@SeasonIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@SeasonIdsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52741, N'Season scope must be an array of Id objects.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@SeasonIdsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max) '$.Id') AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
        ) THROW 52741, N'Season scope contains an invalid Id.', 1;
        INSERT #StatisticSeasons SELECT DISTINCT CONVERT(uniqueidentifier, Id)
        FROM OPENJSON(@SeasonIdsJson) WITH (Id nvarchar(36) '$.Id');
    END
    ELSE
        INSERT #StatisticSeasons
        SELECT Id FROM dbo.Seasons
        WHERE IsPublished = 1 AND (@FromDate IS NULL OR
            (@FromDate < CONVERT(datetime2(7), SeasonEndDate)
             AND @ToDate >= CONVERT(datetime2(7), SeasonStartDate)));

    /* Trigger callers pass exact identities, not a min/max interval spanning
       unrelated seasons. Date covering indexes serve the range aggregates. */
    UPDATE season
    SET PlayCount = plays.PlayCount, ActivePlayCount = plays.ActivePlayCount,
        VoteCount = votes.VoteCount
    FROM dbo.Seasons AS season
    INNER JOIN #StatisticSeasons AS affected ON affected.Id = season.Id
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS PlayCount,
               COALESCE(SUM(CONVERT(bigint, CASE WHEN play.StatusCode = 1 THEN 1 ELSE 0 END)), 0) AS ActivePlayCount
        FROM dbo.Plays AS play
        WHERE play.IsPublished = 1 AND play.IsActive = 1
          AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS plays
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS VoteCount
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE vote.IsPublished = 1 AND vote.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsActive = 1
          AND play.IsPublished = 1 AND play.IsActive = 1
          AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS votes
    WHERE season.IsPublished = 1
      AND (season.PlayCount <> plays.PlayCount OR season.ActivePlayCount <> plays.ActivePlayCount
           OR season.VoteCount <> votes.VoteCount);
END;
