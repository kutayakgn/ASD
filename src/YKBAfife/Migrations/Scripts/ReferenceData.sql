SET XACT_ABORT ON;

/*
   Bootstrap immutable integration rows before foreign keys, procedures and
   Form-to-Play synchronization are installed. Existing code rows are never
   renumbered or replaced; schema validation checks their canonical values.
*/
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000001')
        THROW 51030, 'Reference bootstrap blocked: canonical coordinator role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000001', N'Koordinatör', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 2)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000002')
        THROW 51031, 'Reference bootstrap blocked: canonical jury role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000002', N'Jüri', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 2);
END;

DECLARE @PlayStatuses TABLE
(
    Id uniqueidentifier NOT NULL,
    StatusCode int NOT NULL,
    StatusName nvarchar(100) NOT NULL,
    StatusColor nvarchar(50) NOT NULL
);

INSERT INTO @PlayStatuses (Id, StatusCode, StatusName, StatusColor)
VALUES
    ('30000000-0000-0000-0000-000000000001', 1, N'Oylama Aktif', N'#27ae60'),
    ('30000000-0000-0000-0000-000000000002', 2, N'Değerlendirmeyecek Oyun', N'#d9322d'),
    ('30000000-0000-0000-0000-000000000003', 3, N'Başvuru Yapmayacak Oyun', N'#2CA9E8'),
    ('30000000-0000-0000-0000-000000000004', 4, N'Sahnelenmeyecek Oyun', N'#ac48ed'),
    ('30000000-0000-0000-0000-000000000005', 5, N'Başvurusu Olmayan Oyun', N'#ffffff'),
    ('30000000-0000-0000-0000-000000000006', 6, N'Sistemde Aktif Değil', N'#ffc400');

IF EXISTS
(
    SELECT 1
    FROM @PlayStatuses AS source
    INNER JOIN dbo.PlayStatuses AS target ON target.Id = source.Id
    WHERE target.StatusCode <> source.StatusCode
)
    THROW 51032, 'Reference bootstrap blocked: a canonical PlayStatuses Id is assigned to another code.', 1;

INSERT INTO dbo.PlayStatuses
    (Id, StatusName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, StatusColor)
SELECT source.Id, source.StatusName, source.StatusCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, source.StatusColor
FROM @PlayStatuses AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.PlayStatuses AS target
    WHERE target.StatusCode = source.StatusCode
);

DECLARE @AwardCategories TABLE
(
    Id uniqueidentifier NOT NULL,
    CategoryCode int NOT NULL,
    CategoryName nvarchar(255) NOT NULL,
    MultiCandidate bit NOT NULL,
    HasRoleAndPhoto bit NOT NULL
);

INSERT INTO @AwardCategories (Id, CategoryCode, CategoryName, MultiCandidate, HasRoleAndPhoto)
VALUES
    ('40000000-0000-0000-0000-000000000001', 1001, N'Yılın En Başarılı Oyunu', 0, 0),
    ('40000000-0000-0000-0000-000000000002', 1002, N'Yılın En Başarılı Yönetmeni', 0, 1),
    ('40000000-0000-0000-0000-000000000003', 1003, N'Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000004', 1004, N'Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000005', 1005, N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000006', 1006, N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000007', 1007, N'Yılın En Başarılı Sahne Tasarımı', 0, 0),
    ('40000000-0000-0000-0000-000000000008', 1008, N'Yılın En Başarılı Giysi Tasarımı', 0, 0),
    ('40000000-0000-0000-0000-000000000010', 1009, N'Yılın En Başarılı Sahne Müziği', 0, 0),
    ('40000000-0000-0000-0000-000000000009', 1010, N'Yılın En Başarılı Işık Tasarımı', 0, 0),
    ('40000000-0000-0000-0000-000000000012', 1011, N'Yılın En Başarılı Hareket Düzeni (Kareografisi)', 0, 0),
    ('40000000-0000-0000-0000-000000000011', 1012, N'Yılın En Başarılı Genç Kuşak Sanatçısı', 1, 1);

IF EXISTS
(
    SELECT 1
    FROM @AwardCategories AS source
    INNER JOIN dbo.AwardCategories AS target ON target.Id = source.Id
    WHERE target.CategoryCode <> source.CategoryCode
)
    THROW 51033, 'Reference bootstrap blocked: a canonical AwardCategories Id is assigned to another code.', 1;

INSERT INTO dbo.AwardCategories
    (Id, CategoryName, CategoryCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished)
SELECT source.Id, source.CategoryName, source.CategoryCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1
FROM @AwardCategories AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories AS target
    WHERE target.CategoryCode = source.CategoryCode
);

IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NOT NULL
   AND COL_LENGTH(N'dbo.AwardCategories', N'HasRoleAndPhoto') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
    UPDATE dbo.AwardCategories
    SET MultiCandidate = CASE WHEN CategoryCode IN (1003, 1004, 1005, 1006, 1012) THEN 1 ELSE 0 END,
        HasRoleAndPhoto = CASE WHEN CategoryCode IN (1002, 1003, 1004, 1005, 1006, 1012) THEN 1 ELSE 0 END
    WHERE CategoryCode BETWEEN 1001 AND 1012;';
END;