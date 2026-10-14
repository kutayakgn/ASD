CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.RangeDate),
        @ToDate = MAX(changed.RangeDate)
    FROM
    (
        SELECT CONVERT(datetime2(7), SeasonStartDate) AS RangeDate FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM inserted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonStartDate) FROM deleted
        UNION ALL
        SELECT CONVERT(datetime2(7), SeasonEndDate) FROM deleted
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
