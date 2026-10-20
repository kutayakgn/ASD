SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

/* The four-table production schema supplied on 20 October 2026. Do not add
   modern application tables here: application startup must perform adoption. */
CREATE TABLE dbo.__EFMigrationsHistory
(
    MigrationId nvarchar(150) NOT NULL,
    ProductVersion nvarchar(32) NOT NULL,
    CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY CLUSTERED (MigrationId)
);

CREATE TABLE dbo.Form
(
    Id int IDENTITY(1,1) NOT NULL,
    ApplicationNumber nvarchar(6) NOT NULL,
    SeasonId int NOT NULL,
    CreatedDate datetime NULL CONSTRAINT DF_Form_CreatedDate DEFAULT (GETDATE()),
    UpdatedDate datetime NULL,
    RepertoireName nvarchar(500) NOT NULL,
    TheatreName nvarchar(500) NOT NULL,
    PremiereDate date NOT NULL,
    Display nvarchar(max) NOT NULL,
    ApplicantName nvarchar(100) NOT NULL,
    ApplicantRole nvarchar(200) NOT NULL,
    Phone nvarchar(20) NOT NULL,
    Email nvarchar(150) NOT NULL,
    Director nvarchar(100) NOT NULL,
    ContactName nvarchar(100) NULL,
    ContactPhone nvarchar(20) NULL,
    LeadActress nvarchar(max) NULL,
    LeadActor nvarchar(max) NULL,
    SupportActress nvarchar(max) NULL,
    SupportActor nvarchar(max) NULL,
    StageDesign nvarchar(1000) NULL,
    ClothesDesign nvarchar(1000) NULL,
    LightDesign nvarchar(1000) NULL,
    StageMusic nvarchar(1000) NULL,
    Choreography nvarchar(1000) NULL,
    Active bit NOT NULL CONSTRAINT DF_Form_Active DEFAULT (0),
    Deleted bit NULL CONSTRAINT DF_Form_Deleted DEFAULT (0),
    CONSTRAINT PK_Form PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.Log
(
    Id int IDENTITY(1,1) NOT NULL,
    Title nvarchar(200) NOT NULL,
    Source nvarchar(50) NOT NULL,
    EventType nvarchar(50) NOT NULL,
    Message nvarchar(max) NOT NULL,
    CreatedDate datetime NULL CONSTRAINT DF_Log_CreatedDate DEFAULT (GETDATE()),
    CONSTRAINT PK_Log PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.Manager
(
    Id int IDENTITY(1,1) NOT NULL,
    FullName nchar(100) NOT NULL,
    Email nvarchar(150) NOT NULL,
    Password nvarchar(100) NOT NULL,
    CreatedDate datetime NULL CONSTRAINT DF_Manager_CreatedDate DEFAULT (GETDATE()),
    UpdatedDate datetime NULL CONSTRAINT DF_Manager_UpdatedDate DEFAULT (GETDATE()),
    CONSTRAINT PK_Manager PRIMARY KEY CLUSTERED (Id)
);

/* Identity gaps, unrelated integer season IDs, Unicode, trailing spaces,
   NULL/empty distinctions, long strings and malformed legacy JSON are data,
   and must survive both the archive and canonical copy byte for byte. */
SET IDENTITY_INSERT dbo.Form ON;
INSERT dbo.Form
(
    Id, ApplicationNumber, SeasonId, CreatedDate, UpdatedDate,
    RepertoireName, TheatreName, PremiereDate, Display, ApplicantName,
    ApplicantRole, Phone, Email, Director, ContactName, ContactPhone,
    LeadActress, LeadActor, SupportActress, SupportActor,
    StageDesign, ClothesDesign, LightDesign, StageMusic, Choreography,
    Active, Deleted
)
VALUES
(
    7, N'000007', 93, '2023-10-11T11:12:13.123', '2024-02-14T15:16:17.997',
    REPLICATE(N'Ş', 280) + N' — İstanbul, Çığlık ve Özgürlük  ',
    REPLICATE(N'İ', 300) + N' — Üsküdar Tiyatrosu  ',
    '20230915', N'[{"Date":"2023-10-20","Stage":"Şişli — Büyük Salon"}]  ',
    N'Çağrı Öztürk  ', N'Başvuru / Sahne Yönetmeni  ', N'+90 555 123 45 67  ',
    N'cagri@example.invalid  ', N'İpek Şener  ', N'Öykü Çelik  ', N'',
    N'[{"Name":"Şebnem İnan","Role":"Başrol — A","ImageUrl":null}]  ',
    N'{"Name":"Çağlar Özer","Role":"Başrol — B"}',
    N'Eski serbest metin: kadın yardımcı  ', N'["Aday",17,null,{"Name":"Ad","Role":"Yardımcı"}]  ',
    REPLICATE(N'Ş', 998) + N'  ', REPLICATE(N'Ğ', 1000),
    REPLICATE(N'İ', 1000), REPLICATE(N'Ü', 1000), REPLICATE(N'Ç', 1000),
    1, 0
),
(
    19, N'000019', 94, '2024-02-20T00:00:00', NULL,
    N'Pasif Kayıt', N'Özel Sahne', '20240201', N'bozuk eski gösterim metni  ',
    N'Başvuran', N'Yönetici', N'555', N'pasif@example.invalid', N'Yönetmen',
    NULL, NULL, NULL, N'', N'[]', N'null', NULL, N'', N'[]', N'{}', N'null',
    0, 0
),
(
    120, N'000007', 95, '2022-10-10T01:02:03', NULL,
    N'Silinmiş İlk Başvuru', N'Eski Sahne', '20220910', N'[]',
    N'Eski Başvuran', N'Yönetici', N'555', N'old1@example.invalid', N'Yönetmen',
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    1, 1
),
(
    121, N'000007', 95, '2022-11-10T01:02:03', NULL,
    N'Silinmiş İkinci Başvuru', N'Eski Sahne', '20221010', N'[]',
    N'Eski Başvuran', N'Yönetici', N'555', N'old2@example.invalid', N'Yönetmen',
    N'', NULL, N'', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    0, 1
),
(
    122, N'000122', 96, NULL, NULL,
    N'Tarihsiz ve Deleted NULL', N'Sahne', '20200101', N'',
    N'Başvuran', N'Yönetici', N'555', N'null@example.invalid', N'Yönetmen',
    NULL, N'', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    0, NULL
),
(
    200, N'000200', 999, '2024-06-15T10:20:30', '2024-06-16T00:00:00',
    N'Haziran Kaydı', N'Yaz Sahnesi', '20240601', REPLICATE(CONVERT(nvarchar(max), N'Ş'), 5000),
    N'Başvuran', N'Yönetici', N'555', N'june@example.invalid', N'Yönetmen',
    NULL, NULL, N'[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    1, 0
);
SET IDENTITY_INSERT dbo.Form OFF;

INSERT dbo.Manager (FullName, Email, Password, CreatedDate, UpdatedDate)
VALUES
    (N'Şirket Yöneticisi  ', N'manager@example.invalid  ', N'legacy-hash-unchanged  ',
     '2020-01-02T03:04:05.123', NULL),
    (N'İkinci Yönetici', N'other@example.invalid', N'legacy-other', NULL, NULL);

INSERT dbo.Log (Title, Source, EventType, Message, CreatedDate)
VALUES
    (N'İlk Başvuru  ', N'Eski Sistem  ', N'Bilgi  ',
     N'Özgün kayıt: İstanbul — Şişli  ' + REPLICATE(CONVERT(nvarchar(max), N'Ğ'), 5000),
     '2020-01-02T03:04:05.123'),
    (N'Boş Tarih', N'Form', N'Bilgi', N'', NULL);
