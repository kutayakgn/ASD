CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualWrite
ON dbo.Rankings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshAuthorized')) <> 1
       OR SESSION_CONTEXT(N'RankingsRefreshAuthorized') IS NULL
    BEGIN
        THROW 52002,
            N'Rankings can only be changed by dbo.usp_RefreshRankings.',
            1;
    END;
END;
