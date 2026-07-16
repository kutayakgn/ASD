USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Seed TABLE
    (
        N int NOT NULL PRIMARY KEY,
        GroupName nvarchar(100) NOT NULL,
        StatusName nvarchar(100) NOT NULL,
        CategoryName nvarchar(255) NOT NULL,
        FirstName nvarchar(100) NOT NULL,
        LastName nvarchar(100) NOT NULL,
        PlayName nvarchar(255) NOT NULL,
        Candidate nvarchar(250) NOT NULL
    );

    INSERT INTO @Seed
        ([N], [GroupName], [StatusName], [CategoryName], [FirstName], [LastName], [PlayName], [Candidate])
    VALUES
        (1, N'İstanbul Avrupa Yakası', N'Taslak', N'Yılın En Başarılı Oyunu', N'Deniz', N'Yılmaz', N'Bir Yaz Gecesi', N'Zeynep Yalçın'),
        (2, N'İstanbul Anadolu Yakası', N'Başvuru Alındı', N'Yılın En Başarılı Yönetmeni', N'Aylin', N'Kaya', N'Kırık Saatler', N'Kerem Acar'),
        (3, N'Ankara', N'Ön İncelemede', N'Yılın En Başarılı Kadın Oyuncusu', N'Burak', N'Demir', N'Sessiz Şehir', N'Elif Karaca'),
        (4, N'İzmir', N'Eksik Belge Bekleniyor', N'Yılın En Başarılı Erkek Oyuncusu', N'Ceren', N'Şahin', N'Kayıp Mektuplar', N'Onur Kurt'),
        (5, N'Bursa', N'Değerlendirmede', N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', N'Emre', N'Çelik', N'Son Perde', N'Derya Polat'),
        (6, N'Akdeniz Bölgesi', N'Jüri Atandı', N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', N'Gökçe', N'Arslan', N'Rüzgârın Sesi', N'Barış Eren'),
        (7, N'Karadeniz Bölgesi', N'Oylama Açık', N'Yılın En Başarılı Sahne Tasarımı', N'Hakan', N'Koç', N'Gölgeler Arasında', N'Aslı Tunç'),
        (8, N'İç Anadolu Bölgesi', N'Oylama Tamamlandı', N'Yılın En Başarılı Giysi Tasarımı', N'İpek', N'Aydın', N'Bir İstanbul Hikâyesi', N'Tolga Işık'),
        (9, N'Doğu Anadolu Bölgesi', N'Sonuçlandı', N'Yılın En Başarılı Işık Tasarımı', N'Mert', N'Öztürk', N'Kuşların Şarkısı', N'Pınar Özkan'),
        (10, N'Güneydoğu Anadolu Bölgesi', N'Arşivlendi', N'Yılın En Başarılı Sahne Müziği', N'Selin', N'Aksoy', N'Yarın Başka Bir Gün', N'Can Erdem');

    UPDATE [dbo].[Roles]
    SET [RoleName] = CASE [RoleCode]
        WHEN 1 THEN N'Koordinatör'
        WHEN 2 THEN N'Jüri'
    END
    WHERE [RoleCode] IN (1, 2);

    UPDATE g
    SET g.[GroupName] = s.[GroupName]
    FROM [dbo].[Group] AS g
    INNER JOIN @Seed AS s ON s.[N] = g.[Code];

    UPDATE ps
    SET ps.[StatusName] = s.[StatusName]
    FROM [dbo].[PlayStatuses] AS ps
    INNER JOIN @Seed AS s ON s.[N] = ps.[StatusCode];

    UPDATE ac
    SET ac.[CategoryName] = s.[CategoryName]
    FROM [dbo].[AwardCategories] AS ac
    INNER JOIN @Seed AS s ON s.[N] = ac.[CategoryCode];

    UPDATE u
    SET u.[FirstName] = s.[FirstName],
        u.[LastName] = s.[LastName]
    FROM [dbo].[Users] AS u
    INNER JOIN @Seed AS s
        ON u.[Id] = CONVERT(uniqueidentifier,
            '50000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE p
    SET p.[PlayName] = s.[PlayName],
        p.[TheaterName] = CONCAT('Afife Tiyatro Sahnesi ', s.[N]),
        p.[ContactPersonName] = CONCAT('Yetkili ', s.[N]),
        p.[Address] = CONCAT('Tiyatro Caddesi No: ', s.[N])
    FROM [dbo].[Plays] AS p
    INNER JOIN @Seed AS s
        ON p.[Id] = CONVERT(uniqueidentifier,
            '60000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE pac
    SET pac.[Candidate] = s.[Candidate],
        pac.[Role] = CASE WHEN s.[N] % 2 = 0 THEN N'Yardımcı Rol' ELSE N'Başrol' END
    FROM [dbo].[PlayAwardCategories] AS pac
    INNER JOIN @Seed AS s
        ON pac.[Id] = CONVERT(uniqueidentifier,
            '70000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE a
    SET a.[Text] = CONCAT(N'Duyuru metni ', s.[N]),
        a.[ButtonText] = N'Detayları Gör'
    FROM [dbo].[Announcements] AS a
    INNER JOIN @Seed AS s
        ON a.[Id] = CONVERT(uniqueidentifier,
            'b0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE c
    SET c.[ConfigName] = CONCAT(N'UygulamaAyari', s.[N]),
        c.[ConfigValue] = CONCAT(N'AyarDegeri', s.[N])
    FROM [dbo].[Configs] AS c
    INNER JOIN @Seed AS s
        ON c.[id] = CONVERT(uniqueidentifier,
            'c0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE i
    SET i.[FileName] = CONCAT(N'test-gorsel-', s.[N], N'.txt')
    FROM [dbo].[Images] AS i
    INNER JOIN @Seed AS s
        ON i.[Id] = CONVERT(uniqueidentifier,
            'd0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), s.[N]), 12));

    UPDATE f
    SET f.[RepertoireName] = CONCAT(N'Deneme Repertuvarı ', s.[N]),
        f.[TheatreName] = CONCAT(N'Afife Tiyatrosu ', s.[N]),
        f.[Display] = CONCAT(N'Başvuru gösterim bilgileri ', s.[N]),
        f.[ApplicantName] = CONCAT(N'Başvuru Sahibi ', s.[N]),
        f.[ApplicantRole] = N'Yapımcı',
        f.[Director] = CONCAT(N'Yönetmen ', s.[N]),
        f.[ContactName] = CONCAT(N'İletişim Yetkilisi ', s.[N]),
        f.[LeadActress] = CONCAT(N'Başrol Kadın Oyuncu ', s.[N]),
        f.[LeadActor] = CONCAT(N'Başrol Erkek Oyuncu ', s.[N]),
        f.[SupportActress] = CONCAT(N'Yardımcı Kadın Oyuncu ', s.[N]),
        f.[SupportActor] = CONCAT(N'Yardımcı Erkek Oyuncu ', s.[N]),
        f.[StageDesign] = CONCAT(N'Sahne Tasarımcısı ', s.[N]),
        f.[ClothesDesign] = CONCAT(N'Giysi Tasarımcısı ', s.[N]),
        f.[LightDesign] = CONCAT(N'Işık Tasarımcısı ', s.[N]),
        f.[StageMusic] = CONCAT(N'Besteci ', s.[N]),
        f.[Choreography] = CONCAT(N'Koreograf ', s.[N])
    FROM [dbo].[Form] AS f
    INNER JOIN @Seed AS s
        ON f.[ApplicationNumber] = CONCAT('T', RIGHT('00000' + CONVERT(varchar(5), s.[N]), 5));

    UPDATE m
    SET m.[FullName] = CONCAT(N'Yönetici ', s.[N])
    FROM [dbo].[Manager] AS m
    INNER JOIN @Seed AS s
        ON m.[Email] = CONCAT(N'manager', s.[N], N'@afife.local');

    UPDATE l
    SET l.[Title] = CONCAT(N'Deneme Günlüğü ', s.[N]),
        l.[Source] = N'TestVerisiBetiği',
        l.[EventType] = CASE WHEN s.[N] % 2 = 0 THEN N'Bilgi' ELSE N'Deneme' END,
        l.[Message] = CONCAT(N'Deneme günlük mesajı ', s.[N])
    FROM [dbo].[Log] AS l
    INNER JOIN @Seed AS s
        ON l.[Title] = CONCAT(N'Test Log ', s.[N]) AND l.[Source] = N'SeedScript';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
