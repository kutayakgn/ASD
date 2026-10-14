SET XACT_ABORT ON;

/* Immutable bootstrap for this version, run before its constraints. Existing
   values, IDs and timestamps are preserved; missing rows default to true. */
DECLARE @HomePageTables TABLE
(
    Id uniqueidentifier NOT NULL,
    ConfigName nvarchar(255) NOT NULL
);
INSERT INTO @HomePageTables (Id, ConfigName)
VALUES
    ('60000000-0000-0000-0000-000000000001', N'HomePageJuryTableEnabled'),
    ('60000000-0000-0000-0000-000000000002', N'HomePageMissionTableEnabled'),
    ('60000000-0000-0000-0000-000000000003', N'HomePageMostWatchedTableEnabled'),
    ('60000000-0000-0000-0000-000000000004', N'HomePageLeastWatchedTableEnabled');

IF EXISTS
(
    SELECT target.ConfigName
    FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    GROUP BY target.ConfigName
    HAVING COUNT_BIG(*) > 1
)
    THROW 53210, N'Jüri ana ekran tablo ayarı birden fazla kayda sahip. Veriler korunarak migration durduruldu.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    WHERE target.ConfigName COLLATE Latin1_General_100_BIN2 <> source.ConfigName
       OR DATALENGTH(target.ConfigName) <> DATALENGTH(source.ConfigName)
       OR target.ConfigValue COLLATE Latin1_General_100_BIN2 NOT IN (N'true', N'false')
       OR DATALENGTH(target.ConfigValue) <> CASE WHEN target.ConfigValue COLLATE Latin1_General_100_BIN2 = N'true' THEN 8 ELSE 10 END
)
    THROW 53211, N'Jüri ana ekran tablo ayarının adı veya true/false değeri geçersiz. Mevcut değer değiştirilmedi.', 1;

IF EXISTS
(
    SELECT 1 FROM @HomePageTables AS source
    INNER JOIN dbo.Configs AS target ON target.id = source.Id
    WHERE target.ConfigName <> source.ConfigName
      AND NOT EXISTS (SELECT 1 FROM dbo.Configs AS existing WHERE existing.ConfigName = source.ConfigName)
)
    THROW 53212, N'Jüri ana ekran tablo ayarı için başlangıç ID değeri başka bir kayıtta kullanılıyor.', 1;

DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
INSERT INTO dbo.Configs
    (id, ConfigName, ConfigValue, created_at, created_by, updated_at, updated_by, IsPublished)
SELECT source.Id, source.ConfigName, N'true', @Now, NULL, @Now, NULL, 1
FROM @HomePageTables AS source
WHERE NOT EXISTS (SELECT 1 FROM dbo.Configs AS target WHERE target.ConfigName = source.ConfigName);

UPDATE target SET IsPublished = 1
FROM dbo.Configs AS target
INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
WHERE target.IsPublished = 0;
