CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormCandidates]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @MaximumImageBytes bigint = 150 * 1024 * 1024;

    CREATE TABLE #CandidateSource
    (
        SourceOrder int NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NULL,
        ImageUrl nvarchar(255) NULL,
        Base64 nvarchar(max) NULL
    );

    /* Director is the mandatory, single-slot category 1002 candidate. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT 0, play.Id, 1002, LEFT(LTRIM(RTRIM(formRecord.Director)), 250),
           NULL, 0, NULL, NULL
    FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NOT NULL;

    /* Every category except 1001/1002 creates one role-scoped row per JSON item. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT CONVERT(int, jsonItem.[key]) + 1,
           play.Id,
           category.AwardCategoryCode,
           LEFT(LTRIM(RTRIM(candidateValue.[Name])), 250),
           LEFT(COALESCE
           (
               NULLIF(LTRIM(RTRIM(candidateValue.[Role])), N''),
               NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'')
           ), 200),
           NULL,
           LEFT(NULLIF(LTRIM(RTRIM(candidateValue.ImageUrl)), N''), 255),
           NULLIF(LTRIM(RTRIM(candidateValue.Base64)), N'')
    FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    CROSS APPLY
    (
        VALUES
            (1003, formRecord.LeadActress),
            (1004, formRecord.LeadActor),
            (1005, formRecord.SupportActress),
            (1006, formRecord.SupportActor),
            (1007, formRecord.StageDesign),
            (1008, formRecord.ClothesDesign),
            (1009, formRecord.StageMusic),
            (1010, formRecord.LightDesign),
            (1011, formRecord.Choreography)
    ) AS category(AwardCategoryCode, CandidateJson)
    CROSS APPLY OPENJSON
    (
        CASE
            WHEN ISJSON(category.CandidateJson) <> 1 THEN N'[]'
            WHEN LEFT(LTRIM(category.CandidateJson), 1) = N'[' THEN category.CandidateJson
            ELSE N'[' + category.CandidateJson + N']'
        END
    ) AS jsonItem
    /* Legacy payloads can mix objects with scalar array items. Only objects
       carry named candidate fields; leave the original Form JSON untouched. */
    CROSS APPLY OPENJSON(CASE WHEN jsonItem.[type] = 5 THEN jsonItem.value ELSE N'{}' END)
    WITH
    (
        [Name] nvarchar(250) N'$.Name',
        [Role] nvarchar(200) N'$.Role',
        ImageUrl nvarchar(255) N'$.ImageUrl',
        /* JSON_VALUE silently returns NULL above 4000 characters. Candidate
           photos are intentionally read as nvarchar(max) instead. */
        Base64 nvarchar(max) N'$.Base64'
    ) AS candidateValue
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'') IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #CandidateSource
        WHERE AwardCategoryCode BETWEEN 1003 AND 1011
          AND NULLIF(LTRIM(RTRIM(Role)), N'') IS NULL
    )
        THROW 52410, N'Çok adaylı kategorilerde Role alanı zorunludur.', 1;

    /* Repair legacy rows that point to the same Form array slot. Keep the most
       relevant row on the slot; release later rows so the remaining-source
       backfill below can map them to slot 2, 3, ... without deleting history. */
    ;WITH RankedMappedSlots AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS SlotOccurrence
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = NULL,
        IsCurrent = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RankedMappedSlots AS mappedSlot ON mappedSlot.Id = candidate.Id
    WHERE mappedSlot.SlotOccurrence > 1;

    /* SourceOrder is the stable Form slot identity. Candidate and Role are
       editable descriptions; duplicate role names are valid distinct slots. */
    ;WITH SourceMatches AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(source.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(source.Role, N''))))
                   ORDER BY source.SourceOrder
               ) AS MatchOrder
        FROM #CandidateSource AS source
    ),
    ExistingMatches AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               candidate.Candidate, candidate.Role,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(candidate.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(candidate.Role, N''))))
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS MatchOrder
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN ExistingMatches AS existing ON existing.Id = candidate.Id
    INNER JOIN SourceMatches AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND LOWER(LTRIM(RTRIM(source.Candidate))) = LOWER(LTRIM(RTRIM(existing.Candidate)))
       AND LOWER(LTRIM(RTRIM(COALESCE(source.Role, N'')))) =
           LOWER(LTRIM(RTRIM(COALESCE(existing.Role, N''))))
       AND source.MatchOrder = existing.MatchOrder
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories AS mapped
        WHERE mapped.PlayId = source.PlayId
          AND mapped.AwardCategoryCode = source.AwardCategoryCode
          AND mapped.SourceFormCandidateOrder = source.SourceOrder
    );

    /* Backfill old procedure-created rows which predate source-slot tracking. */
    ;WITH RemainingSources AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode
                   ORDER BY source.SourceOrder
               ) AS SlotOrder
        FROM #CandidateSource AS source
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.PlayAwardCategories AS mapped
            WHERE mapped.PlayId = source.PlayId
              AND mapped.AwardCategoryCode = source.AwardCategoryCode
              AND mapped.SourceFormCandidateOrder = source.SourceOrder
        )
    ),
    RemainingCandidates AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS SlotOrder
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RemainingCandidates AS existing ON existing.Id = candidate.Id
    INNER JOIN RemainingSources AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND source.SlotOrder = existing.SlotOrder;

    UPDATE source
    SET RoleCode = existing.RoleCode
    FROM #CandidateSource AS source
    CROSS APPLY
    (
        SELECT TOP (1) candidate.RoleCode
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.PlayId = source.PlayId
          AND candidate.AwardCategoryCode = source.AwardCategoryCode
          AND candidate.SourceFormCandidateOrder = source.SourceOrder
        ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                 COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC, candidate.Id
    ) AS existing
    WHERE source.AwardCategoryCode <> 1002;

    /* Only an exact (play, category, RoleCode, candidate) repetition is
       forbidden. Different candidates may intentionally share a RoleCode.
       Repair only legacy slots that would become an exact duplicate. */
    ;WITH DuplicateSourceRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode, source.RoleCode,
                                LOWER(LTRIM(RTRIM(source.Candidate)))
                   ORDER BY source.SourceOrder
               ) AS RoleOccurrence
        FROM #CandidateSource AS source
        WHERE source.AwardCategoryCode BETWEEN 1003 AND 1011
          AND source.RoleCode > 0
    )
    UPDATE source
    SET RoleCode = NULL
    FROM #CandidateSource AS source
    INNER JOIN DuplicateSourceRoles AS duplicateRole
        ON duplicateRole.PlayId = source.PlayId
       AND duplicateRole.AwardCategoryCode = source.AwardCategoryCode
       AND duplicateRole.SourceOrder = source.SourceOrder
    WHERE duplicateRole.RoleOccurrence > 1;

    ;WITH MissingRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               COALESCE
               (
                   (SELECT MAX(candidate.RoleCode)
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.PlayId = source.PlayId AND candidate.RoleCode > 0),
                   0
               ) + ROW_NUMBER() OVER
                   (PARTITION BY source.PlayId ORDER BY source.AwardCategoryCode, source.SourceOrder) AS NewRoleCode
        FROM #CandidateSource AS source
        WHERE source.Role IS NOT NULL AND source.RoleCode IS NULL
    )
    UPDATE source
    SET RoleCode = missing.NewRoleCode
    FROM #CandidateSource AS source
    INNER JOIN MissingRoles AS missing
        ON missing.PlayId = source.PlayId
       AND missing.AwardCategoryCode = source.AwardCategoryCode
       AND missing.SourceOrder = source.SourceOrder;

    /* Form changes update only the mapped slot. Existing published/current
       candidates retain their manually selected status. A retired source slot
       becoming current again starts active, just like a newly created slot. */
    ;WITH CurrentTargets AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS TargetOrder
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
    )
    UPDATE candidate
    SET Candidate = source.Candidate,
        Role = source.Role,
        RoleCode = source.RoleCode,
        IsPublished = 1,
        IsActive = CASE
            WHEN candidate.IsPublished = 1 AND candidate.IsCurrent = 1
                THEN candidate.IsActive
            ELSE 1 END,
        IsCurrent = 1,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN CurrentTargets AS target
        ON target.Id = candidate.Id AND target.TargetOrder = 1
    INNER JOIN #CandidateSource AS source
        ON source.PlayId = candidate.PlayId
       AND source.AwardCategoryCode = candidate.AwardCategoryCode
       AND source.SourceOrder = candidate.SourceFormCandidateOrder;

    /* A non-empty valid Base64 value replaces the mapped candidate photo.
       Empty/invalid legacy values preserve the existing image. */
    CREATE TABLE #UpdatedCandidateImages
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        OldImageId uniqueidentifier NULL,
        NewImageId uniqueidentifier NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NOT NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #UpdatedCandidateImages
        (CandidateId, OldImageId, NewImageId, ImageUrl, CleanBase64)
    SELECT candidate.Id, candidate.PhotoImageId, NEWID(), source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.PlayId = source.PlayId
       AND candidate.AwardCategoryCode = source.AwardCategoryCode
       AND candidate.SourceFormCandidateOrder = source.SourceOrder
       AND candidate.IsCurrent = 1
    WHERE source.Base64 IS NOT NULL;

    UPDATE image
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("image.CleanBase64"))', 'varbinary(max)')
    FROM #UpdatedCandidateImages AS image
    WHERE LEN(image.CleanBase64) % 4 = 0
      AND image.CleanBase64 COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[^A-Za-z0-9+/=]%';

    UPDATE image
    SET ContentType = CASE
        WHEN SUBSTRING(image.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(image.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(image.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(image.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #UpdatedCandidateImages AS image
    WHERE image.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #UpdatedCandidateImages
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT image.NewImageId,
           COALESCE(NULLIF(image.ImageUrl, N''),
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), image.CandidateId),
                           CASE image.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           image.ContentType, image.ImageData, @Now, image.CandidateId, 1
    FROM #UpdatedCandidateImages AS image
    LEFT JOIN dbo.Images AS currentImage ON currentImage.Id = image.OldImageId
    WHERE image.ContentType IS NOT NULL
      AND DATALENGTH(image.ImageData) BETWEEN 1 AND @MaximumImageBytes
      AND
      (
          currentImage.Id IS NULL
          OR currentImage.IsPublished = 0
          OR currentImage.ContentType <> image.ContentType
          OR DATALENGTH(currentImage.ImageData) <> DATALENGTH(image.ImageData)
          OR currentImage.ImageData <> image.ImageData
      );

    UPDATE candidate
    SET PhotoImageId = image.NewImageId,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #UpdatedCandidateImages AS image ON image.CandidateId = candidate.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = image.NewImageId;

    UPDATE oldImage
    SET IsPublished = 0,
        UpdatedAt = @Now
    FROM dbo.Images AS oldImage
    INNER JOIN #UpdatedCandidateImages AS replacement
        ON replacement.OldImageId = oldImage.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = replacement.NewImageId
    WHERE oldImage.IsPublished = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.PlayAwardCategories AS candidate
          WHERE candidate.PhotoImageId = oldImage.Id
            AND candidate.IsPublished = 1
      );

    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE candidate.SourceFormCandidateOrder IS NOT NULL
      AND formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM #CandidateSource AS source
          WHERE source.PlayId = candidate.PlayId
            AND source.AwardCategoryCode = candidate.AwardCategoryCode
            AND source.SourceOrder = candidate.SourceFormCandidateOrder
      )
      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1);

    CREATE TABLE #NewCandidates
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        ImageId uniqueidentifier NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NOT NULL,
        SourceOrder int NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #NewCandidates
        (CandidateId, ImageId, PlayId, AwardCategoryCode, Candidate, Role,
         RoleCode, SourceOrder, ImageUrl, CleanBase64)
    SELECT NEWID(), CASE WHEN source.Base64 IS NULL THEN NULL ELSE NEWID() END,
           source.PlayId, source.AwardCategoryCode, source.Candidate, source.Role,
           COALESCE(source.RoleCode, 0), source.SourceOrder, source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = source.PlayId
          AND existing.AwardCategoryCode = source.AwardCategoryCode
          AND existing.RoleCode = COALESCE(source.RoleCode, 0)
          AND LOWER(LTRIM(RTRIM(existing.Candidate))) =
              LOWER(LTRIM(RTRIM(source.Candidate)))
          AND existing.IsPublished = 1
    );

    /* Legacy/test Forms can contain placeholder strings in Base64. They must not
       block candidate backfill and must never be persisted as image bytes. */
    UPDATE candidate
    SET ImageId = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL
      AND
      (
          LEN(candidate.CleanBase64) % 4 <> 0
          OR candidate.CleanBase64 COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/=]%'
      );

    UPDATE candidate
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("candidate.CleanBase64"))', 'varbinary(max)')
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL;

    UPDATE candidate
    SET ContentType = CASE
        WHEN SUBSTRING(candidate.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(candidate.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(candidate.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(candidate.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #NewCandidates
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    UPDATE candidate
    SET ImageId = NULL, ImageData = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL
      AND
      (
          DATALENGTH(candidate.ImageData) = 0
          OR DATALENGTH(candidate.ImageData) > @MaximumImageBytes
          OR candidate.ContentType IS NULL
      );

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT candidate.ImageId,
           COALESCE(NULLIF(candidate.ImageUrl, N''),
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), candidate.CandidateId),
                           CASE candidate.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           candidate.ContentType, candidate.ImageData, @Now, candidate.CandidateId, 1
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageId IS NOT NULL;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, IsActive, Candidate, AwardCategoryCode,
        IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
    )
    SELECT candidate.CandidateId, candidate.PlayId, @Now, NULL, NULL, NULL,
           1, 1, candidate.Candidate, candidate.AwardCategoryCode,
           1, candidate.Role, candidate.RoleCode, candidate.ImageId, candidate.SourceOrder
    FROM #NewCandidates AS candidate;
END;
