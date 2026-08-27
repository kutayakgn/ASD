/* A published blacklist entry immediately removes matching votes from circulation. */
CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_DeactivateJuryVotes]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vote
    SET vote.[IsPublished] = 0,
        vote.[IsActive] = 0,
        vote.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[JuryVotes] AS vote
    INNER JOIN [dbo].[PlayAwardCategories] AS candidate
        ON candidate.[Id] = vote.[PlayAwardCategoryId]
    INNER JOIN inserted AS blacklist
        ON blacklist.[JuryId] = vote.[JuryId]
       AND blacklist.[PlayId] = candidate.[PlayId]
       AND blacklist.[IsPublished] = 1
    WHERE vote.[IsPublished] = 1
       OR vote.[IsActive] = 1;
END;
