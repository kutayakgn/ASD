IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Announcements' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Announcements] (
        [Id] [uniqueidentifier] NOT NULL,
        [AnnouncementLocationId] [int] NOT NULL,
        [Text] [nvarchar](255) NULL,
        [ButtonText] [nvarchar](255) NULL,
        [ButtonLink] [nvarchar](max) NULL,
        [ImageId] [uniqueidentifier] NULL,
        [BackgroundImageId] [uniqueidentifier] NULL,
        [BackgroundColor] [nvarchar](50) NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        CONSTRAINT [PK_Announcements] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AwardCategories' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[AwardCategories] (
        [Id] [uniqueidentifier] NOT NULL,
        [CategoryName] [nvarchar](255) NOT NULL,
        [CategoryCode] [int] NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        CONSTRAINT [PK_AwardCategories] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Configs' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Configs] (
        [id] [uniqueidentifier] NOT NULL,
        [ConfigName] [nvarchar](255) NOT NULL,
        [ConfigValue] [nvarchar](255) NOT NULL,
        [created_at] [datetime2](7) NOT NULL,
        [created_by] [uniqueidentifier] NULL,
        [updated_at] [datetime2](7) NOT NULL,
        [updated_by] [uniqueidentifier] NULL,
        CONSTRAINT [PK_Configs] PRIMARY KEY CLUSTERED ([id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Form' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Form] (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [ApplicationNumber] [nvarchar](6) NOT NULL,
        [SeasonId] [int] NOT NULL,
        [CreatedDate] [datetime] NULL,
        [UpdatedDate] [datetime] NULL,
        [RepertoireName] [nvarchar](500) NOT NULL,
        [TheatreName] [nvarchar](500) NOT NULL,
        [PremiereDate] [date] NOT NULL,
        [Display] [nvarchar](max) NOT NULL,
        [ApplicantName] [nvarchar](100) NOT NULL,
        [ApplicantRole] [nvarchar](200) NOT NULL,
        [Phone] [nvarchar](20) NOT NULL,
        [Email] [nvarchar](150) NOT NULL,
        [Director] [nvarchar](100) NOT NULL,
        [ContactName] [nvarchar](100) NULL,
        [ContactPhone] [nvarchar](20) NULL,
        [LeadActress] [nvarchar](max) NULL,
        [LeadActor] [nvarchar](max) NULL,
        [SupportActress] [nvarchar](max) NULL,
        [SupportActor] [nvarchar](max) NULL,
        [StageDesign] [nvarchar](1000) NULL,
        [ClothesDesign] [nvarchar](1000) NULL,
        [LightDesign] [nvarchar](1000) NULL,
        [StageMusic] [nvarchar](1000) NULL,
        [Choreography] [nvarchar](1000) NULL,
        [Active] [bit] NOT NULL,
        [Deleted] [bit] NULL,
        CONSTRAINT [PK_Form] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Group' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Group] (
        [Id] [uniqueidentifier] NOT NULL,
        [Code] [int] NOT NULL,
        [GroupName] [nvarchar](100) NOT NULL,
        [CreatedAt] [datetime2](7) NOT NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        CONSTRAINT [PK_Group] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Images' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Images] (
        [Id] [uniqueidentifier] NOT NULL,
        [FileName] [nvarchar](255) NOT NULL,
        [ContentType] [nvarchar](100) NOT NULL,
        [ImageData] [varbinary](max) NOT NULL,
        [CreatedAt] [datetime2](7) NOT NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NOT NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        CONSTRAINT [PK_Images] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'JuryAssignedPlays' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[JuryAssignedPlays] (
        [Id] [uniqueidentifier] NOT NULL,
        [PlayId] [uniqueidentifier] NOT NULL,
        [CreatedAt] [datetime2](7) NOT NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [JuryId] [uniqueidentifier] NOT NULL,
        CONSTRAINT [PK_JuryAssignedPlays] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'JuryGameTicketFees' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[JuryGameTicketFees] (
        [Id] [uniqueidentifier] NOT NULL,
        [UserId] [uniqueidentifier] NOT NULL,
        [PlayId] [uniqueidentifier] NOT NULL,
        [TicketFee] [decimal](10, 2) NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        CONSTRAINT [PK_JuryGameTicketFees] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'JuryVotes' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[JuryVotes] (
        [Id] [uniqueidentifier] NOT NULL,
        [PlayAwardCategoryId] [uniqueidentifier] NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [Score] [int] NOT NULL,
        [JuryId] [uniqueidentifier] NOT NULL,
        CONSTRAINT [PK_JuryVotes] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Log' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Log] (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [Title] [nvarchar](200) NOT NULL,
        [Source] [nvarchar](50) NOT NULL,
        [EventType] [nvarchar](50) NOT NULL,
        [Message] [nvarchar](max) NOT NULL,
        [CreatedDate] [datetime] NULL,
        CONSTRAINT [PK_Log] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Manager' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Manager] (
        [Id] [int] IDENTITY(1,1) NOT NULL,
        [FullName] [nchar](100) NOT NULL,
        [Email] [nvarchar](150) NOT NULL,
        [Password] [nvarchar](100) NOT NULL,
        [CreatedDate] [datetime] NULL,
        [UpdatedDate] [datetime] NULL,
        CONSTRAINT [PK_Manager] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PlayAwardCategories' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[PlayAwardCategories] (
        [Id] [uniqueidentifier] NOT NULL,
        [PlayId] [uniqueidentifier] NOT NULL,
        [PhotoImageId] [uniqueidentifier] NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [Candidate] [nvarchar](250) NOT NULL,
        [AwardCategoryCode] [int] NOT NULL,
        [IsCurrent] [bit] NOT NULL,
        [Role] [nvarchar](200) NULL,
        [RoleCode] [int] NOT NULL,
        [IsOld] [bit] NOT NULL,
        CONSTRAINT [PK_PlayAwardCategories] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Plays' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Plays] (
        [Id] [uniqueidentifier] NOT NULL,
        [PlayName] [nvarchar](255) NOT NULL,
        [StatusCode] [int] NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [Slug] [varchar](255) NOT NULL,
        [TheaterName] [varchar](255) NOT NULL,
        [Phone] [varchar](255) NULL,
        [ContactPersonName] [varchar](255) NULL,
        [ContactPersonPhone] [varchar](255) NULL,
        [Address] [varchar](255) NULL,
        [Email] [varchar](255) NULL,
        CONSTRAINT [PK_Plays] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PlayStatuses' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[PlayStatuses] (
        [Id] [uniqueidentifier] NOT NULL,
        [StatusName] [nvarchar](100) NOT NULL,
        [StatusCode] [int] NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [StatusColor] [nvarchar](50) NULL,
        CONSTRAINT [PK_PlayStatuses] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Roles' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Roles] (
        [Id] [uniqueidentifier] NOT NULL,
        [RoleName] [nvarchar](100) NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [RoleCode] [int] NOT NULL,
        CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Users' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Users] (
        [Id] [uniqueidentifier] NOT NULL,
        [FirstName] [nvarchar](100) NOT NULL,
        [LastName] [nvarchar](100) NOT NULL,
        [Phone] [nvarchar](30) NULL,
        [PhotoImageId] [uniqueidentifier] NULL,
        [Username] [nvarchar](100) NOT NULL,
        [PasswordHash] [nvarchar](500) NOT NULL,
        [Email] [nvarchar](255) NOT NULL,
        [CreatedAt] [datetime2](7) NULL,
        [CreatedBy] [uniqueidentifier] NULL,
        [UpdatedAt] [datetime2](7) NULL,
        [UpdatedBy] [uniqueidentifier] NULL,
        [IsPublished] [bit] NOT NULL,
        [RoleCode] [int] NOT NULL,
        [GroupCode] [int] NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED ([Id])
    );
END;
GO
