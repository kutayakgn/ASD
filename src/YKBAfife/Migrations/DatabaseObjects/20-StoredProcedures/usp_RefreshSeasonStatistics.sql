CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshSeasonStatistics]
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;

    UPDATE season
    SET
        PlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        ActivePlayCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.Plays AS play
            WHERE play.IsPublished = 1
              AND play.IsActive = 1
              AND play.StatusCode = 1
              AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        ),
        VoteCount =
        (
            SELECT COUNT_BIG(*)
            FROM dbo.JuryVotes AS vote
            INNER JOIN dbo.PlayAwardCategories AS candidate
                ON candidate.Id = vote.PlayAwardCategoryId
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
              AND candidate.IsPublished = 1
              AND candidate.IsActive = 1
              AND play.IsPublished = 1
              AND play.IsActive = 1
              AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
              AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        )
    FROM dbo.Seasons AS season
    WHERE season.IsPublished = 1
      AND
      (
          @FromDate IS NULL
          OR
          (
              @FromDate < CONVERT(datetime2(7), season.SeasonEndDate)
              AND @ToDate >= CONVERT(datetime2(7), season.SeasonStartDate)
          )
      );
END;
