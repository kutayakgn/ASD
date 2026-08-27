CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshRankings
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayAwardCategoryId)
           OR UPDATE(Score)
           OR UPDATE(IsPublished)
           OR UPDATE(IsActive)
       )
        RETURN;

    EXEC dbo.usp_RefreshRankings;
END;
