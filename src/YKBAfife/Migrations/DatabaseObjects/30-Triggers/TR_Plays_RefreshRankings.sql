CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshRankings
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(RecordType) OR UPDATE(IsPublished))
        RETURN;

    EXEC dbo.usp_RefreshRankings;
END;
