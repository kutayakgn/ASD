/* Defense in depth: a blacklisted jury/play pair cannot publish a vote. */
CREATE OR ALTER TRIGGER [dbo].[TR_JuryVotes_BlockBlacklistedJuryPlay]
ON [dbo].[JuryVotes]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS vote
        INNER JOIN [dbo].[PlayAwardCategories] AS candidate
            ON candidate.[Id] = vote.[PlayAwardCategoryId]
        INNER JOIN [dbo].[Blacklist] AS blacklist
            ON blacklist.[JuryId] = vote.[JuryId]
           AND blacklist.[PlayId] = candidate.[PlayId]
           AND blacklist.[IsPublished] = 1
        WHERE vote.[IsPublished] = 1
           OR vote.[IsActive] = 1
    )
    BEGIN
        THROW 51214, N'Blacklist kaydı bulunan jüri bu oyun için oy veremez.', 1;
    END;
END;
