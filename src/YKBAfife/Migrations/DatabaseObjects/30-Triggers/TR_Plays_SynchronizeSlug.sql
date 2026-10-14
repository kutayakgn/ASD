CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSlug
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(PlayName)
        RETURN;

    DECLARE @PlayId uniqueidentifier;
    DECLARE @PlayName nvarchar(255);
    DECLARE @BaseSlug varchar(255);
    DECLARE @Slug varchar(255);
    DECLARE @Suffix varchar(12);
    DECLARE @Counter int;

    DECLARE ChangedPlays CURSOR LOCAL FAST_FORWARD FOR
        SELECT insertedRecord.Id, insertedRecord.PlayName
        FROM inserted AS insertedRecord
        INNER JOIN deleted AS deletedRecord ON deletedRecord.Id = insertedRecord.Id
        WHERE ISNULL(insertedRecord.PlayName, N'') <> ISNULL(deletedRecord.PlayName, N'')
        ORDER BY insertedRecord.Id;

    OPEN ChangedPlays;
    FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @BaseSlug = dbo.ufn_CreatePlaySlug(@PlayName);
        SET @Slug = @BaseSlug;
        SET @Counter = 2;

        WHILE EXISTS
        (
            SELECT 1
            FROM dbo.Plays WITH (UPDLOCK, HOLDLOCK)
            WHERE Id <> @PlayId
              AND Slug = @Slug
        )
        BEGIN
            SET @Suffix = '-' + CONVERT(varchar(10), @Counter);
            SET @Slug = LEFT(@BaseSlug, 255 - LEN(@Suffix)) + @Suffix;
            SET @Counter += 1;
        END;

        UPDATE dbo.Plays
        SET Slug = @Slug
        WHERE Id = @PlayId
          AND ISNULL(Slug, '') <> @Slug;

        FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;
    END;

    CLOSE ChangedPlays;
    DEALLOCATE ChangedPlays;
END;
