CREATE OR ALTER FUNCTION dbo.ufn_CreatePlaySlug(@Value nvarchar(255))
RETURNS varchar(255)
AS
BEGIN
    DECLARE @Input nvarchar(255) = ISNULL(@Value, N'');
    DECLARE @Result varchar(255) = '';
    DECLARE @Position int = 1;
    DECLARE @PendingSeparator bit = 0;
    DECLARE @Character nchar(1);
    DECLARE @CodePoint int;

    WHILE @Position <= LEN(@Input) AND LEN(@Result) < 255
    BEGIN
        SET @Character = SUBSTRING(@Input, @Position, 1);
        SET @Character = CASE @Character COLLATE Latin1_General_100_BIN2
            WHEN N'ç' THEN N'c' WHEN N'Ç' THEN N'c'
            WHEN N'ğ' THEN N'g' WHEN N'Ğ' THEN N'g'
            WHEN N'ı' THEN N'i' WHEN N'İ' THEN N'i'
            WHEN N'ö' THEN N'o' WHEN N'Ö' THEN N'o'
            WHEN N'ş' THEN N's' WHEN N'Ş' THEN N's'
            WHEN N'ü' THEN N'u' WHEN N'Ü' THEN N'u'
            ELSE LOWER(@Character COLLATE Latin1_General_100_CI_AS)
        END;
        SET @CodePoint = UNICODE(@Character);

        IF @CodePoint BETWEEN 48 AND 57 OR @CodePoint BETWEEN 97 AND 122
        BEGIN
            IF @PendingSeparator = 1 AND LEN(@Result) > 0
            BEGIN
                IF LEN(@Result) >= 254
                    BREAK;

                SET @Result += '-';
            END;

            IF LEN(@Result) < 255
                SET @Result += CONVERT(varchar(1), @Character);

            SET @PendingSeparator = 0;
        END
        ELSE IF LEN(@Result) > 0
            SET @PendingSeparator = 1;

        SET @Position += 1;
    END;

    RETURN CASE WHEN LEN(@Result) = 0 THEN 'oyun' ELSE @Result END;
END;
