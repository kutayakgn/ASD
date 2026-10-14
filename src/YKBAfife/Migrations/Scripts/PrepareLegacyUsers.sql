IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
    RETURN;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Users
    WHERE LEN(Username) NOT BETWEEN 3 AND 30
       OR DATALENGTH(Username) <> LEN(Username) * 2
       OR Username COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9._]%'
)
    RETURN;

IF COL_LENGTH(N'dbo.Users', N'LegacyUsername') IS NULL
    ALTER TABLE dbo.Users ADD LegacyUsername nvarchar(100) NULL;

EXEC sys.sp_executesql N'
    UPDATE dbo.Users
    SET LegacyUsername = COALESCE(LegacyUsername, Username)
    WHERE LEN(Username) NOT BETWEEN 3 AND 30
       OR DATALENGTH(Username) <> LEN(Username) * 2
       OR Username COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9._]%'';';

DECLARE
    @Id uniqueidentifier,
    @RoleCode int,
    @IsPublished bit,
    @Original nvarchar(100),
    @Normalized nvarchar(30),
    @Character nchar(1),
    @Position int,
    @Suffix int;

DECLARE invalid_user_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT Id, RoleCode, IsPublished, Username
FROM dbo.Users
WHERE LEN(Username) NOT BETWEEN 3 AND 30
   OR DATALENGTH(Username) <> LEN(Username) * 2
   OR Username COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9._]%'
ORDER BY Id;

OPEN invalid_user_cursor;
FETCH NEXT FROM invalid_user_cursor
INTO @Id, @RoleCode, @IsPublished, @Original;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Normalized = N'';
    SET @Position = 1;

    WHILE @Position <= LEN(@Original) AND LEN(@Normalized) < 30
    BEGIN
        SET @Character = SUBSTRING(@Original, @Position, 1);
        IF @Character COLLATE Latin1_General_100_BIN2 LIKE N'[A-Za-z0-9._]'
            SET @Normalized += @Character;
        ELSE IF LEN(@Normalized) > 0 AND RIGHT(@Normalized, 1) <> N'_'
            SET @Normalized += N'_';
        SET @Position += 1;
    END;

    SET @Normalized = LEFT(LTRIM(RTRIM(@Normalized)), 30);
    IF LEN(@Normalized) < 3
        SET @Normalized = LEFT(N'user_' + REPLACE(CONVERT(nvarchar(36), @Id), N'-', N''), 30);

    SET @Suffix = 0;
    WHILE @IsPublished = 1 AND EXISTS
    (
        SELECT 1
        FROM dbo.Users AS existing
        WHERE existing.Id <> @Id
          AND existing.RoleCode = @RoleCode
          AND existing.IsPublished = 1
          AND existing.Username = @Normalized
    )
    BEGIN
        SET @Suffix += 1;
        SET @Normalized = LEFT(@Normalized, 21) + N'_' +
            RIGHT(N'00000000' + CONVERT(nvarchar(8), @Suffix), 8);
    END;

    UPDATE dbo.Users SET Username = @Normalized WHERE Id = @Id;

    FETCH NEXT FROM invalid_user_cursor
    INTO @Id, @RoleCode, @IsPublished, @Original;
END;

CLOSE invalid_user_cursor;
DEALLOCATE invalid_user_cursor;
