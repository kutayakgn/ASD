CREATE OR ALTER TRIGGER dbo.TR_Images_EnforceMaximumSize
ON dbo.Images
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Retiring an existing legacy image does not upload or change its content.
       INSERT and every write to the image payload still receive all checks. */
    IF NOT (UPDATE(FileName) OR UPDATE(ContentType) OR UPDATE(ImageData))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE
            (ContentType = N'image/jpeg' AND
                (LOWER(FileName) NOT LIKE N'%.jpg' AND LOWER(FileName) NOT LIKE N'%.jpeg'))
            OR (ContentType = N'image/png' AND LOWER(FileName) NOT LIKE N'%.png')
            OR (ContentType = N'image/webp' AND LOWER(FileName) NOT LIKE N'%.webp')
            OR ContentType NOT IN (N'image/jpeg', N'image/png', N'image/webp')
            OR
            (
                ContentType = N'image/jpeg'
                AND (DATALENGTH(ImageData) < 3 OR SUBSTRING(ImageData, 1, 3) <> 0xFFD8FF)
            )
            OR
            (
                ContentType = N'image/png'
                AND
                (
                    DATALENGTH(ImageData) < 8
                    OR SUBSTRING(ImageData, 1, 8) <> 0x89504E470D0A1A0A
                )
            )
            OR
            (
                ContentType = N'image/webp'
                AND
                (
                    DATALENGTH(ImageData) < 12
                    OR SUBSTRING(ImageData, 1, 4) <> 0x52494646
                    OR SUBSTRING(ImageData, 9, 4) <> 0x57454250
                )
            )
    )
        THROW 52432,
            N'Yalnızca dosya uzantısı, içerik türü ve imzası doğrulanan JPEG, PNG veya WebP görseller yüklenebilir.',
            1;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE DATALENGTH(ImageData) > 150 * 1024 * 1024
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;
END;
