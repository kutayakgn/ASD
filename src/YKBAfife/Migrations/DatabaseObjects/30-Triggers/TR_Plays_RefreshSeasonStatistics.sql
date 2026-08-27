CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(CreatedAt) OR UPDATE(IsPublished) OR UPDATE(IsActive) OR UPDATE(StatusCode))
    BEGIN
        RETURN;
    END;

    DECLARE @FromDate datetime2(7);
    DECLARE @ToDate datetime2(7);

    SELECT
        @FromDate = MIN(changed.CreatedAt),
        @ToDate = MAX(changed.CreatedAt)
    FROM
    (
        SELECT CreatedAt FROM inserted WHERE CreatedAt IS NOT NULL
        UNION ALL
        SELECT CreatedAt FROM deleted WHERE CreatedAt IS NOT NULL
    ) AS changed;

    IF @FromDate IS NOT NULL
    BEGIN
        EXEC dbo.usp_RefreshSeasonStatistics @FromDate, @ToDate;
    END;
END;
