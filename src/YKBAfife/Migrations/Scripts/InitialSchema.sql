CREATE TABLE [dbo].[AdditionalVotingJuries](
	[Id] [uniqueidentifier] NOT NULL,
	[AdditionalVotingId] [uniqueidentifier] NOT NULL,
	[JuryId] [uniqueidentifier] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_AdditionalVotingJuries] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AdditionalVotingPlays]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AdditionalVotingPlays](
	[Id] [uniqueidentifier] NOT NULL,
	[AdditionalVotingId] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_AdditionalVotingPlays] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AdditionalVotings]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AdditionalVotings](
	[Id] [uniqueidentifier] NOT NULL,
	[StartDate] [date] NOT NULL,
	[EndDate] [date] NOT NULL,
	[AppliesToAllJuries] [bit] NOT NULL,
	[AppliesToAllPlays] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_AdditionalVotings] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AdditionalVotingUsages]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AdditionalVotingUsages](
	[Id] [uniqueidentifier] NOT NULL,
	[AdditionalVotingId] [uniqueidentifier] NOT NULL,
	[JuryId] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[UsageType] [tinyint] NOT NULL,
	[UsedAt] [datetime2](7) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_AdditionalVotingUsages] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AdminLogs]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AdminLogs](
	[Id] [uniqueidentifier] NOT NULL,
	[CorrelationId] [uniqueidentifier] NOT NULL,
	[UserId] [uniqueidentifier] NULL,
	[Username] [nvarchar](100) NULL,
	[OperationName] [nvarchar](256) NOT NULL,
	[OperationType] [nvarchar](30) NOT NULL,
	[SchemaName] [nvarchar](128) NULL,
	[TableName] [nvarchar](128) NULL,
	[EntityKey] [nvarchar](max) NULL,
	[OldValues] [nvarchar](max) NULL,
	[NewValues] [nvarchar](max) NULL,
	[AffectedRowCount] [int] NOT NULL,
	[OccurredAt] [datetime2](7) NOT NULL,
	[IpAddress] [nvarchar](64) NULL,
	[UserAgent] [nvarchar](1000) NULL,
	[Application] [nvarchar](100) NOT NULL,
	[HttpMethod] [nvarchar](16) NULL,
	[RequestPath] [nvarchar](2048) NULL,
	[ControllerName] [nvarchar](128) NULL,
	[ActionName] [nvarchar](128) NULL,
	[Source] [nvarchar](50) NOT NULL,
	[IsSuccessful] [bit] NOT NULL,
	[Details] [nvarchar](max) NULL,
	[FailureReason] [nvarchar](2000) NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_AdminLogs] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JuryLogs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JuryLogs](
    [Id] [uniqueidentifier] NOT NULL,
    [CorrelationId] [uniqueidentifier] NOT NULL,
    [JuryId] [uniqueidentifier] NULL,
    [JuryUsername] [nvarchar](100) NULL,
    [PlayId] [uniqueidentifier] NULL,
    [PlayName] [nvarchar](250) NULL,
    [AdditionalVotingId] [uniqueidentifier] NULL,
    [AdditionalVotingUsageId] [uniqueidentifier] NULL,
    [AdditionalVotingUsageType] [tinyint] NULL,
    [IsAdditionalVoting] [bit] NOT NULL,
    [OperationName] [nvarchar](256) NOT NULL,
    [OperationType] [nvarchar](50) NOT NULL,
    [SubmittedVotesJson] [nvarchar](max) NULL,
    [OldVotesJson] [nvarchar](max) NULL,
    [NewVotesJson] [nvarchar](max) NULL,
    [SubmittedTicketFee] [decimal](10,2) NULL,
    [OldTicketFee] [decimal](10,2) NULL,
    [NewTicketFee] [decimal](10,2) NULL,
    [RequestPayloadJson] [nvarchar](max) NULL,
    [StateSnapshotJson] [nvarchar](max) NULL,
    [AffectedVoteCount] [int] NOT NULL,
    [OccurredAt] [datetime2](7) NOT NULL,
    [DurationMilliseconds] [bigint] NULL,
    [IpAddress] [nvarchar](64) NULL,
    [UserAgent] [nvarchar](1000) NULL,
    [HttpMethod] [nvarchar](16) NULL,
    [RequestPath] [nvarchar](2048) NULL,
    [ControllerName] [nvarchar](128) NULL,
    [ActionName] [nvarchar](128) NULL,
    [Application] [nvarchar](100) NOT NULL,
    [Source] [nvarchar](50) NOT NULL,
    [IsSuccessful] [bit] NOT NULL,
    [ResultCode] [nvarchar](100) NULL,
    [Details] [nvarchar](max) NULL,
    [FailureReason] [nvarchar](2000) NULL,
    [IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_JuryLogs] PRIMARY KEY CLUSTERED ([Id] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Announcements]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Announcements](
	[Id] [uniqueidentifier] NOT NULL,
	[AnnouncementLocationId] [int] NOT NULL,
	[Text] [nvarchar](255) NULL,
	[ButtonText] [nvarchar](255) NULL,
	[ButtonLink] [nvarchar](max) NULL,
	[BackgroundColor] [nvarchar](50) NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[ImageId] [uniqueidentifier] NULL,
	[BackgroundImageId] [uniqueidentifier] NULL,
 CONSTRAINT [PK_Announcements] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AwardCategories]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AwardCategories](
	[Id] [uniqueidentifier] NOT NULL,
	[CategoryName] [nvarchar](255) NOT NULL,
	[CategoryCode] [int] NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[MultiCandidate] [bit] NOT NULL,
	[HasRoleAndPhoto] [bit] NOT NULL,
 CONSTRAINT [PK_AwardCategories] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AwardCategories_CategoryCode] UNIQUE NONCLUSTERED 
(
	[CategoryCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Blacklist]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Blacklist](
	[Id] [uniqueidentifier] NOT NULL,
	[JuryId] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[CreatedBy] [uniqueidentifier] NOT NULL,
	[CreatedOn] [datetime2](0) NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Blacklist] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Configs]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Configs](
	[id] [uniqueidentifier] NOT NULL,
	[ConfigName] [nvarchar](255) NOT NULL,
	[ConfigValue] [nvarchar](255) NOT NULL,
	[created_at] [datetime2](7) NOT NULL,
	[created_by] [uniqueidentifier] NULL,
	[updated_at] [datetime2](7) NOT NULL,
	[updated_by] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Configs] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Form]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Form](
	[ApplicationNumber] [nvarchar](6) NOT NULL,
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
	[YoungGenerationArtist] [nvarchar](max) NULL,
	[IsPublished] [bit] NOT NULL,
	[Id] [uniqueidentifier] NOT NULL,
	[LegacyId] [int] NULL,
	[SeasonId] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_Form] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[FormLifecycleStates]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FormLifecycleStates](
	[Id] [uniqueidentifier] NOT NULL,
	[FormId] [uniqueidentifier] NOT NULL,
	[EntityName] [nvarchar](64) NOT NULL,
	[EntityId] [uniqueidentifier] NOT NULL,
	[WasPublished] [bit] NOT NULL,
	[WasActive] [bit] NULL,
	[WasJuriOylamaStatus] [bit] NULL,
	[WasKunyeGirisStatus] [bit] NULL,
	[WasStatusCode] [int] NULL,
	[DeactivatedAt] [datetime2](7) NOT NULL,
	[RestoredAt] [datetime2](7) NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_FormLifecycleStates] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Group]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Group](
	[Id] [uniqueidentifier] NOT NULL,
	[Code] [int] NOT NULL,
	[GroupName] [nvarchar](100) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Group] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Group_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Images]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Images](
	[Id] [uniqueidentifier] NOT NULL,
	[FileName] [nvarchar](255) NOT NULL,
	[ContentType] [nvarchar](100) NOT NULL,
	[ImageData] [varbinary](max) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NOT NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Images] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JuryAssignedPlays]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JuryAssignedPlays](
	[Id] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[JuryId] [uniqueidentifier] NOT NULL,
 CONSTRAINT [PK_JuryAssignedPlays] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JuryGameTicketFees]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JuryGameTicketFees](
	[Id] [uniqueidentifier] NOT NULL,
	[UserId] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[TicketFee] [decimal](10, 2) NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_JuryGameTicketFees] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[JuryVotes]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JuryVotes](
	[Id] [uniqueidentifier] NOT NULL,
	[PlayAwardCategoryId] [uniqueidentifier] NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[Score] [int] NOT NULL,
	[JuryId] [uniqueidentifier] NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_JuryVotes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Log]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Log](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Title] [nvarchar](200) NOT NULL,
	[Source] [nvarchar](50) NOT NULL,
	[EventType] [nvarchar](50) NOT NULL,
	[Message] [nvarchar](max) NOT NULL,
	[CreatedDate] [datetime] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Log] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Manager]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Manager](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[FullName] [nchar](100) NOT NULL,
	[Email] [nvarchar](150) NOT NULL,
	[Password] [nvarchar](100) NOT NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedDate] [datetime] NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Manager] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PlayAwardCategories]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PlayAwardCategories](
	[Id] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
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
	[SourceFormCandidateOrder] [int] NULL,
	[PhotoImageId] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_PlayAwardCategories] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Plays]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Plays](
	[Id] [uniqueidentifier] NOT NULL,
	[PlayName] [nvarchar](255) NOT NULL,
	[StatusCode] [int] NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[Slug] [varchar](255) NOT NULL,
	[TheaterName] [nvarchar](255) NOT NULL,
	[Phone] [nvarchar](255) NULL,
	[ContactPersonName] [nvarchar](255) NULL,
	[ContactPersonPhone] [nvarchar](255) NULL,
	[Address] [nvarchar](255) NULL,
	[Email] [nvarchar](255) NULL,
	[JuriOylamaStatus] [bit] NOT NULL,
	[KunyeGirisStatus] [bit] NOT NULL,
	[RecordType] [bit] NOT NULL,
	[SourceFormId] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_Plays] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PlayStatuses]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PlayStatuses](
	[Id] [uniqueidentifier] NOT NULL,
	[StatusName] [nvarchar](100) NOT NULL,
	[StatusCode] [int] NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[StatusColor] [nvarchar](50) NULL,
 CONSTRAINT [PK_PlayStatuses] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_PlayStatuses_StatusCode] UNIQUE NONCLUSTERED 
(
	[StatusCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Rankings]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rankings](
	[Id] [uniqueidentifier] NOT NULL,
	[PlayId] [uniqueidentifier] NOT NULL,
	[PlayAwardCategoryId] [uniqueidentifier] NOT NULL,
	[NumberOfActiveVote] [int] NOT NULL,
	[ArithmeticMean] [float] NULL,
	[TrimmedMean] [float] NULL,
	[ArithmeticRank] [int] NULL,
	[TrimmedRank] [int] NULL,
	[ArithmeticVariance] [float] NULL,
	[IsPublished] [bit] NOT NULL,
	[ConfidenceValue] [int] NULL,
 CONSTRAINT [PK_Rankings] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Roles](
	[Id] [uniqueidentifier] NOT NULL,
	[RoleName] [nvarchar](100) NOT NULL,
	[CreatedAt] [datetime2](7) NULL,
	[CreatedBy] [uniqueidentifier] NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[IsPublished] [bit] NOT NULL,
	[RoleCode] [int] NOT NULL,
 CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Roles_RoleCode] UNIQUE NONCLUSTERED 
(
	[RoleCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Seasons]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Seasons](
	[Id] [uniqueidentifier] NOT NULL,
	[SeasonStartDate] [date] NOT NULL,
	[SeasonEndDate] [date] NOT NULL,
	[KunyeRegistrationStartDate] [date] NOT NULL,
	[KunyeRegistrationEndDate] [date] NOT NULL,
	[VotingStartDate] [date] NOT NULL,
	[VotingEndDate] [date] NOT NULL,
	[PlayCount] [int] NOT NULL,
	[ActivePlayCount] [int] NOT NULL,
	[VoteCount] [int] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_Seasons] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
	[Id] [uniqueidentifier] NOT NULL,
	[FirstName] [nvarchar](100) NOT NULL,
	[LastName] [nvarchar](100) NOT NULL,
	[Phone] [nvarchar](30) NULL,
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
	[PhotoImageId] [uniqueidentifier] NULL,
	[IsActive] [bit] NOT NULL,
	[IsJuryPresident] [bit] NOT NULL,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[UsersLog]    Script Date: 3.08.2026 15:17:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UsersLog](
	[Id] [uniqueidentifier] NOT NULL,
	[UserId] [uniqueidentifier] NULL,
	[ActorUserId] [uniqueidentifier] NULL,
	[Username] [nvarchar](100) NOT NULL,
	[EventType] [nvarchar](50) NOT NULL,
	[IsSuccessful] [bit] NOT NULL,
	[OccurredAt] [datetime2](7) NOT NULL,
	[IpAddress] [nvarchar](64) NULL,
	[UserAgent] [nvarchar](1000) NULL,
	[Application] [nvarchar](100) NOT NULL,
	[Details] [nvarchar](2000) NULL,
	[FailureReason] [nvarchar](500) NULL,
	[OldValue] [nvarchar](max) NULL,
	[NewValue] [nvarchar](max) NULL,
	[CorrelationId] [uniqueidentifier] NOT NULL,
	[IsPublished] [bit] NOT NULL,
 CONSTRAINT [PK_UsersLog] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Index [UX_AdditionalVotingJuries_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_AdditionalVotingJuries_Published] ON [dbo].[AdditionalVotingJuries]
(
	[AdditionalVotingId] ASC,
	[JuryId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_AdditionalVotingPlays_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_AdditionalVotingPlays_Published] ON [dbo].[AdditionalVotingPlays]
(
	[AdditionalVotingId] ASC,
	[PlayId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_AdditionalVotingUsages_Lookup]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_AdditionalVotingUsages_Lookup] ON [dbo].[AdditionalVotingUsages]
(
	[AdditionalVotingId] ASC,
	[UsageType] ASC,
	[JuryId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_AdditionalVotingUsages_OneTime]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_AdditionalVotingUsages_OneTime] ON [dbo].[AdditionalVotingUsages]
(
	[AdditionalVotingId] ASC,
	[JuryId] ASC,
	[PlayId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_AdminLogs_CorrelationId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_AdminLogs_CorrelationId] ON [dbo].[AdminLogs]
(
	[CorrelationId] ASC,
	[OccurredAt] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_AdminLogs_FilterConsole]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_AdminLogs_FilterConsole] ON [dbo].[AdminLogs]
(
	[OccurredAt] DESC,
	[OperationType] ASC,
	[SchemaName] ASC,
	[TableName] ASC,
	[ActionName] ASC
)
INCLUDE([CorrelationId],[Username],[IsPublished]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_AdminLogs_TableName_OccurredAt]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_AdminLogs_TableName_OccurredAt] ON [dbo].[AdminLogs]
(
	[TableName] ASC,
	[OccurredAt] DESC
)
INCLUDE([OperationType],[UserId],[IsPublished]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_AdminLogs_UserId_OccurredAt]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_AdminLogs_UserId_OccurredAt] ON [dbo].[AdminLogs]
(
	[UserId] ASC,
	[OccurredAt] DESC
)
INCLUDE([OperationType],[TableName],[IsSuccessful],[IsPublished]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Announcements_BackgroundImageId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Announcements_BackgroundImageId] ON [dbo].[Announcements]
(
	[BackgroundImageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Announcements_ImageId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Announcements_ImageId] ON [dbo].[Announcements]
(
	[ImageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Blacklist_CreatedOn]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Blacklist_CreatedOn] ON [dbo].[Blacklist]
(
	[CreatedOn] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_Blacklist_JuryId_PlayId_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Blacklist_JuryId_PlayId_Published] ON [dbo].[Blacklist]
(
	[JuryId] ASC,
	[PlayId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Form_ApplicationNumber_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Form_ApplicationNumber_Published] ON [dbo].[Form]
(
	[ApplicationNumber] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object: Index [UX_Form_LegacyId] ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Form_LegacyId] ON [dbo].[Form]
(
    [LegacyId] ASC
)
WHERE ([LegacyId] IS NOT NULL)
GO
/****** Object:  Index [UX_FormLifecycleStates_OpenEntity]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_FormLifecycleStates_OpenEntity] ON [dbo].[FormLifecycleStates]
(
	[FormId] ASC,
	[EntityName] ASC,
	[EntityId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryAssignedPlays_JuryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryAssignedPlays_JuryId] ON [dbo].[JuryAssignedPlays]
(
	[JuryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryAssignedPlays_PlayId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryAssignedPlays_PlayId] ON [dbo].[JuryAssignedPlays]
(
	[PlayId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_JuryAssignedPlays_PlayId_JuryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_JuryAssignedPlays_PlayId_JuryId] ON [dbo].[JuryAssignedPlays]
(
	[PlayId] ASC,
	[JuryId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryGameTicketFees_PlayId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryGameTicketFees_PlayId] ON [dbo].[JuryGameTicketFees]
(
	[PlayId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryGameTicketFees_UserId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryGameTicketFees_UserId] ON [dbo].[JuryGameTicketFees]
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_JuryGameTicketFees_UserId_PlayId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_JuryGameTicketFees_UserId_PlayId] ON [dbo].[JuryGameTicketFees]
(
	[UserId] ASC,
	[PlayId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryVotes_JuryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryVotes_JuryId] ON [dbo].[JuryVotes]
(
	[JuryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryVotes_PlayAwardCategoryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryVotes_PlayAwardCategoryId] ON [dbo].[JuryVotes]
(
	[PlayAwardCategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryVotes_RankingProjection]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryVotes_RankingProjection] ON [dbo].[JuryVotes]
(
	[PlayAwardCategoryId] ASC,
	[IsPublished] ASC,
	[IsActive] ASC
)
INCLUDE([Score],[Id]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_JuryVotes_SeasonStatistics]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_JuryVotes_SeasonStatistics] ON [dbo].[JuryVotes]
(
	[CreatedAt] ASC
)
INCLUDE([IsPublished],[IsActive]) 
WHERE ([CreatedAt] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_JuryVotes_JuryId_PlayAwardCategoryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_JuryVotes_JuryId_PlayAwardCategoryId] ON [dbo].[JuryVotes]
(
	[PlayAwardCategoryId] ASC,
	[JuryId] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PlayAwardCategories_AwardCategoryCode]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_PlayAwardCategories_AwardCategoryCode] ON [dbo].[PlayAwardCategories]
(
	[AwardCategoryCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PlayAwardCategories_PhotoImageId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_PlayAwardCategories_PhotoImageId] ON [dbo].[PlayAwardCategories]
(
	[PhotoImageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PlayAwardCategories_PlayId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_PlayAwardCategories_PlayId] ON [dbo].[PlayAwardCategories]
(
	[PlayId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_PlayAwardCategories_Current_Play_Category_Role]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PlayAwardCategories_Current_Play_Category_Role] ON [dbo].[PlayAwardCategories]
(
	[PlayId] ASC,
	[AwardCategoryCode] ASC,
	[RoleCode] ASC,
	[IsCurrent] ASC
)
WHERE ([IsCurrent]=(1) AND [IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object: Index [IX_JuryLogs_CorrelationId] ******/
CREATE NONCLUSTERED INDEX [IX_JuryLogs_CorrelationId] ON [dbo].[JuryLogs] ([CorrelationId] ASC)
GO
/****** Object: Index [IX_JuryLogs_JuryId_OccurredAt] ******/
CREATE NONCLUSTERED INDEX [IX_JuryLogs_JuryId_OccurredAt] ON [dbo].[JuryLogs]
(
    [JuryId] ASC,
    [OccurredAt] DESC
)
GO
/****** Object: Index [IX_JuryLogs_PlayId_OccurredAt] ******/
CREATE NONCLUSTERED INDEX [IX_JuryLogs_PlayId_OccurredAt] ON [dbo].[JuryLogs]
(
    [PlayId] ASC,
    [OccurredAt] DESC
)
GO
/****** Object: Index [IX_JuryLogs_OperationType_IsSuccessful_OccurredAt] ******/
CREATE NONCLUSTERED INDEX [IX_JuryLogs_OperationType_IsSuccessful_OccurredAt] ON [dbo].[JuryLogs]
(
    [OperationType] ASC,
    [IsSuccessful] ASC,
    [OccurredAt] DESC
)
GO
/****** Object:  Index [UX_PlayAwardCategories_FormSourceSlot] ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PlayAwardCategories_FormSourceSlot] ON [dbo].[PlayAwardCategories]
(
	[PlayId] ASC,
	[AwardCategoryCode] ASC,
	[SourceFormCandidateOrder] ASC
)
WHERE ([SourceFormCandidateOrder] IS NOT NULL AND [IsCurrent]=(1))
GO
/****** Object:  Index [UX_PlayAwardCategories_DefaultPlayCategory]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PlayAwardCategories_DefaultPlayCategory] ON [dbo].[PlayAwardCategories]
(
	[PlayId] ASC
)
WHERE ([AwardCategoryCode]=(1001) AND [RoleCode]=(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_PlayAwardCategories_Play_Category_Role_Candidate]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_PlayAwardCategories_Play_Category_Role_Candidate] ON [dbo].[PlayAwardCategories]
(
	[PlayId] ASC,
	[AwardCategoryCode] ASC,
	[RoleCode] ASC,
	[Candidate] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Plays_SeasonStatistics]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Plays_SeasonStatistics] ON [dbo].[Plays]
(
	[CreatedAt] ASC
)
INCLUDE([IsPublished],[StatusCode]) 
WHERE ([CreatedAt] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Plays_StatusCode]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Plays_StatusCode] ON [dbo].[Plays]
(
	[StatusCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_Plays_SourceFormId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Plays_SourceFormId] ON [dbo].[Plays]
(
	[SourceFormId] ASC
)
WHERE ([SourceFormId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Rankings_PlayId_IsPublished]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Rankings_PlayId_IsPublished] ON [dbo].[Rankings]
(
	[PlayId] ASC,
	[IsPublished] ASC
)
INCLUDE([PlayAwardCategoryId],[NumberOfActiveVote],[ArithmeticMean],[TrimmedMean],[ArithmeticRank],[TrimmedRank],[ArithmeticVariance]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_Rankings_PlayAwardCategoryId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Rankings_PlayAwardCategoryId] ON [dbo].[Rankings]
(
	[PlayAwardCategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_Seasons_PublishedDateRange]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Seasons_PublishedDateRange] ON [dbo].[Seasons]
(
	[SeasonStartDate] ASC,
	[SeasonEndDate] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Users_GroupCode]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Users_GroupCode] ON [dbo].[Users]
(
	[GroupCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Users_PhotoImageId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Users_PhotoImageId] ON [dbo].[Users]
(
	[PhotoImageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Users_RoleCode]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_Users_RoleCode] ON [dbo].[Users]
(
	[RoleCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_OnePublishedJuryPresident] ON [dbo].[Users]
(
	[IsJuryPresident] ASC
)
WHERE ([IsPublished]=(1) AND [IsJuryPresident]=(1))
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Users_RoleCode_Email_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_RoleCode_Email_Published] ON [dbo].[Users]
(
	[RoleCode] ASC,
	[Email] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_Users_RoleCode_Username_Published]    Script Date: 3.08.2026 15:17:26 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Users_RoleCode_Username_Published] ON [dbo].[Users]
(
	[RoleCode] ASC,
	[Username] ASC
)
WHERE ([IsPublished]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UsersLog_CorrelationId]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_UsersLog_CorrelationId] ON [dbo].[UsersLog]
(
	[CorrelationId] ASC,
	[OccurredAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UsersLog_FilterConsole]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_UsersLog_FilterConsole] ON [dbo].[UsersLog]
(
	[OccurredAt] DESC,
	[Application] ASC
)
INCLUDE([UserId],[ActorUserId],[Username],[CorrelationId],[IsPublished]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UsersLog_UserId_EventType_OccurredAt]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_UsersLog_UserId_EventType_OccurredAt] ON [dbo].[UsersLog]
(
	[UserId] ASC,
	[EventType] ASC,
	[OccurredAt] DESC
)
INCLUDE([IsSuccessful],[IsPublished]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UsersLog_Username_OccurredAt]    Script Date: 3.08.2026 15:17:26 ******/
CREATE NONCLUSTERED INDEX [IX_UsersLog_Username_OccurredAt] ON [dbo].[UsersLog]
(
	[Username] ASC,
	[OccurredAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] ADD  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] ADD  CONSTRAINT [DF_AdditionalVotingJuries_CreatedAt]  DEFAULT (sysdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] ADD  CONSTRAINT [DF_AdditionalVotingJuries_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] ADD  CONSTRAINT [DF_AdditionalVotingJuries_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] ADD  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] ADD  CONSTRAINT [DF_AdditionalVotingPlays_CreatedAt]  DEFAULT (sysdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] ADD  CONSTRAINT [DF_AdditionalVotingPlays_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] ADD  CONSTRAINT [DF_AdditionalVotingPlays_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  CONSTRAINT [DF_AdditionalVotings_AllJuries]  DEFAULT ((0)) FOR [AppliesToAllJuries]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  CONSTRAINT [DF_AdditionalVotings_AllPlays]  DEFAULT ((0)) FOR [AppliesToAllPlays]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  CONSTRAINT [DF_AdditionalVotings_CreatedAt]  DEFAULT (sysdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  CONSTRAINT [DF_AdditionalVotings_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AdditionalVotings] ADD  CONSTRAINT [DF_AdditionalVotings_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] ADD  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] ADD  CONSTRAINT [DF_AdditionalVotingUsages_UsedAt]  DEFAULT (sysdatetime()) FOR [UsedAt]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] ADD  CONSTRAINT [DF_AdditionalVotingUsages_CreatedAt]  DEFAULT (sysdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] ADD  CONSTRAINT [DF_AdditionalVotingUsages_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] ADD  CONSTRAINT [DF_AdditionalVotingUsages_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AdminLogs] ADD  CONSTRAINT [DF_AdminLogs_AffectedRowCount]  DEFAULT ((0)) FOR [AffectedRowCount]
GO
ALTER TABLE [dbo].[AdminLogs] ADD  CONSTRAINT [DF_AdminLogs_Application]  DEFAULT (N'AfifeAdmin') FOR [Application]
GO
ALTER TABLE [dbo].[AdminLogs] ADD  CONSTRAINT [DF_AdminLogs_IsSuccessful]  DEFAULT ((1)) FOR [IsSuccessful]
GO
ALTER TABLE [dbo].[AdminLogs] ADD  CONSTRAINT [DF_AdminLogs_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_Id] DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_CorrelationId] DEFAULT (newid()) FOR [CorrelationId]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_IsAdditionalVoting] DEFAULT ((0)) FOR [IsAdditionalVoting]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_AffectedVoteCount] DEFAULT ((0)) FOR [AffectedVoteCount]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_OccurredAt] DEFAULT (DATEADD(HOUR, (3), SYSUTCDATETIME())) FOR [OccurredAt]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_Application] DEFAULT (N'AfifeJury') FOR [Application]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_Source] DEFAULT (N'JuryPanel') FOR [Source]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_IsSuccessful] DEFAULT ((0)) FOR [IsSuccessful]
GO
ALTER TABLE [dbo].[JuryLogs] ADD CONSTRAINT [DF_JuryLogs_IsPublished] DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Announcements] ADD  CONSTRAINT [DF_Announcements_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AwardCategories] ADD  CONSTRAINT [DF_AwardCategories_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AwardCategories] ADD  CONSTRAINT [DF_AwardCategories_MultiCandidate]  DEFAULT ((0)) FOR [MultiCandidate]
GO
ALTER TABLE [dbo].[AwardCategories] ADD  CONSTRAINT [DF_AwardCategories_HasRoleAndPhoto]  DEFAULT ((0)) FOR [HasRoleAndPhoto]
GO
ALTER TABLE [dbo].[Blacklist] ADD  CONSTRAINT [DF_Blacklist_Id]  DEFAULT (newid()) FOR [Id]
GO
ALTER TABLE [dbo].[Blacklist] ADD  CONSTRAINT [DF_Blacklist_CreatedOn]  DEFAULT (sysutcdatetime()) FOR [CreatedOn]
GO
ALTER TABLE [dbo].[Blacklist] ADD  CONSTRAINT [DF_Blacklist_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Configs] ADD  CONSTRAINT [DF_Configs_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Form] ADD  CONSTRAINT [DF_Form_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Form] ADD  CONSTRAINT [DF_Form_Id]  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[Form] ADD  CONSTRAINT [DF_Form_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[FormLifecycleStates] ADD  CONSTRAINT [DF_FormLifecycleStates_Id]  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[FormLifecycleStates] ADD  CONSTRAINT [DF_FormLifecycleStates_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Group] ADD  CONSTRAINT [DF_Group_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Images] ADD  CONSTRAINT [DF_Images_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[JuryAssignedPlays] ADD  CONSTRAINT [DF_JuryAssignedPlays_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[JuryGameTicketFees] ADD  CONSTRAINT [DF_JuryGameTicketFees_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[JuryVotes] ADD  CONSTRAINT [DF_JuryVotes_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[JuryVotes] ADD  CONSTRAINT [DF_JuryVotes_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Log] ADD  CONSTRAINT [DF_Log_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Manager] ADD  CONSTRAINT [DF_Manager_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[PlayAwardCategories] ADD  CONSTRAINT [DF_PlayAwardCategories_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[PlayAwardCategories] ADD  CONSTRAINT [DF_PlayAwardCategories_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Plays] ADD  CONSTRAINT [DF_Plays_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Plays] ADD  CONSTRAINT [DF_Plays_JuriOylamaStatus]  DEFAULT ((0)) FOR [JuriOylamaStatus]
GO
ALTER TABLE [dbo].[Plays] ADD  CONSTRAINT [DF_Plays_KunyeGirisStatus]  DEFAULT ((0)) FOR [KunyeGirisStatus]
GO
ALTER TABLE [dbo].[Plays] ADD  CONSTRAINT [DF_Plays_RecordType]  DEFAULT ((0)) FOR [RecordType]
GO
ALTER TABLE [dbo].[Plays] ADD  CONSTRAINT [DF_Plays_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[PlayStatuses] ADD  CONSTRAINT [DF_PlayStatuses_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Rankings] ADD  CONSTRAINT [DF_Rankings_Id]  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[Rankings] ADD  CONSTRAINT [DF_Rankings_NumberOfActiveVote]  DEFAULT ((0)) FOR [NumberOfActiveVote]
GO
ALTER TABLE [dbo].[Rankings] ADD  CONSTRAINT [DF_Rankings_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Roles] ADD  CONSTRAINT [DF_Roles_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Seasons] ADD  CONSTRAINT [DF_Seasons_Id]  DEFAULT (newsequentialid()) FOR [Id]
GO
ALTER TABLE [dbo].[Seasons] ADD  CONSTRAINT [DF_Seasons_PlayCount]  DEFAULT ((0)) FOR [PlayCount]
GO
ALTER TABLE [dbo].[Seasons] ADD  CONSTRAINT [DF_Seasons_ActivePlayCount]  DEFAULT ((0)) FOR [ActivePlayCount]
GO
ALTER TABLE [dbo].[Seasons] ADD  CONSTRAINT [DF_Seasons_VoteCount]  DEFAULT ((0)) FOR [VoteCount]
GO
ALTER TABLE [dbo].[Seasons] ADD  CONSTRAINT [DF_Seasons_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_IsPublished_SoftDelete]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[Users] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Users] ADD CONSTRAINT [DF_Users_IsJuryPresident]
DEFAULT ((0)) FOR [IsJuryPresident]
GO
ALTER TABLE [dbo].[UsersLog] ADD  CONSTRAINT [DF_UsersLog_Username]  DEFAULT (N'') FOR [Username]
GO
ALTER TABLE [dbo].[UsersLog] ADD  CONSTRAINT [DF_UsersLog_Application]  DEFAULT (N'AfifeAdmin') FOR [Application]
GO
ALTER TABLE [dbo].[UsersLog] ADD  CONSTRAINT [DF_UsersLog_IsPublished]  DEFAULT ((1)) FOR [IsPublished]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingJuries_AdditionalVotings] FOREIGN KEY([AdditionalVotingId])
REFERENCES [dbo].[AdditionalVotings] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] CHECK CONSTRAINT [FK_AdditionalVotingJuries_AdditionalVotings]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingJuries_Users_CreatedBy] FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] CHECK CONSTRAINT [FK_AdditionalVotingJuries_Users_CreatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingJuries_Users_Jury] FOREIGN KEY([JuryId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] CHECK CONSTRAINT [FK_AdditionalVotingJuries_Users_Jury]
GO
ALTER TABLE [dbo].[AdditionalVotingJuries]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingJuries_Users_UpdatedBy] FOREIGN KEY([UpdatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingJuries] CHECK CONSTRAINT [FK_AdditionalVotingJuries_Users_UpdatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingPlays_AdditionalVotings] FOREIGN KEY([AdditionalVotingId])
REFERENCES [dbo].[AdditionalVotings] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] CHECK CONSTRAINT [FK_AdditionalVotingPlays_AdditionalVotings]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingPlays_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] CHECK CONSTRAINT [FK_AdditionalVotingPlays_Plays]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingPlays_Users_CreatedBy] FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] CHECK CONSTRAINT [FK_AdditionalVotingPlays_Users_CreatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotingPlays]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingPlays_Users_UpdatedBy] FOREIGN KEY([UpdatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingPlays] CHECK CONSTRAINT [FK_AdditionalVotingPlays_Users_UpdatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotings]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotings_Users_CreatedBy] FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotings] CHECK CONSTRAINT [FK_AdditionalVotings_Users_CreatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotings]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotings_Users_UpdatedBy] FOREIGN KEY([UpdatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotings] CHECK CONSTRAINT [FK_AdditionalVotings_Users_UpdatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingUsages_AdditionalVotings] FOREIGN KEY([AdditionalVotingId])
REFERENCES [dbo].[AdditionalVotings] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [FK_AdditionalVotingUsages_AdditionalVotings]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingUsages_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [FK_AdditionalVotingUsages_Plays]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingUsages_Users_CreatedBy] FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [FK_AdditionalVotingUsages_Users_CreatedBy]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingUsages_Users_Jury] FOREIGN KEY([JuryId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [FK_AdditionalVotingUsages_Users_Jury]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [FK_AdditionalVotingUsages_Users_UpdatedBy] FOREIGN KEY([UpdatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [FK_AdditionalVotingUsages_Users_UpdatedBy]
GO
ALTER TABLE [dbo].[Announcements]  WITH CHECK ADD  CONSTRAINT [FK_Announcements_Images_BackgroundImageId] FOREIGN KEY([BackgroundImageId])
REFERENCES [dbo].[Images] ([Id])
GO
ALTER TABLE [dbo].[Announcements] CHECK CONSTRAINT [FK_Announcements_Images_BackgroundImageId]
GO
ALTER TABLE [dbo].[Announcements]  WITH CHECK ADD  CONSTRAINT [FK_Announcements_Images_ImageId] FOREIGN KEY([ImageId])
REFERENCES [dbo].[Images] ([Id])
GO
ALTER TABLE [dbo].[Announcements] CHECK CONSTRAINT [FK_Announcements_Images_ImageId]
GO
ALTER TABLE [dbo].[Blacklist]  WITH CHECK ADD  CONSTRAINT [FK_Blacklist_Plays_PlayId] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
GO
ALTER TABLE [dbo].[Blacklist] CHECK CONSTRAINT [FK_Blacklist_Plays_PlayId]
GO
ALTER TABLE [dbo].[Blacklist]  WITH CHECK ADD  CONSTRAINT [FK_Blacklist_Users_CreatedBy] FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[Blacklist] CHECK CONSTRAINT [FK_Blacklist_Users_CreatedBy]
GO
ALTER TABLE [dbo].[Blacklist]  WITH CHECK ADD  CONSTRAINT [FK_Blacklist_Users_JuryId] FOREIGN KEY([JuryId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[Blacklist] CHECK CONSTRAINT [FK_Blacklist_Users_JuryId]
GO
ALTER TABLE [dbo].[Form]  WITH CHECK ADD  CONSTRAINT [FK_Form_Seasons] FOREIGN KEY([SeasonId])
REFERENCES [dbo].[Seasons] ([Id])
GO
ALTER TABLE [dbo].[Form] CHECK CONSTRAINT [FK_Form_Seasons]
GO
ALTER TABLE [dbo].[FormLifecycleStates]  WITH CHECK ADD  CONSTRAINT [FK_FormLifecycleStates_Form] FOREIGN KEY([FormId])
REFERENCES [dbo].[Form] ([Id])
GO
ALTER TABLE [dbo].[FormLifecycleStates] CHECK CONSTRAINT [FK_FormLifecycleStates_Form]
GO
ALTER TABLE [dbo].[JuryAssignedPlays]  WITH CHECK ADD  CONSTRAINT [FK_JuryAssignedPlays_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryAssignedPlays] CHECK CONSTRAINT [FK_JuryAssignedPlays_Plays]
GO
ALTER TABLE [dbo].[JuryAssignedPlays]  WITH CHECK ADD  CONSTRAINT [FK_JuryAssignedPlays_Users] FOREIGN KEY([JuryId])
REFERENCES [dbo].[Users] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryAssignedPlays] CHECK CONSTRAINT [FK_JuryAssignedPlays_Users]
GO
ALTER TABLE [dbo].[JuryGameTicketFees]  WITH CHECK ADD  CONSTRAINT [FK_JuryGameTicketFees_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryGameTicketFees] CHECK CONSTRAINT [FK_JuryGameTicketFees_Plays]
GO
ALTER TABLE [dbo].[JuryGameTicketFees]  WITH CHECK ADD  CONSTRAINT [FK_JuryGameTicketFees_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryGameTicketFees] CHECK CONSTRAINT [FK_JuryGameTicketFees_Users]
GO
ALTER TABLE [dbo].[JuryLogs] WITH CHECK ADD CONSTRAINT [FK_JuryLogs_AdditionalVotings_AdditionalVotingId]
FOREIGN KEY([AdditionalVotingId]) REFERENCES [dbo].[AdditionalVotings] ([Id])
GO
ALTER TABLE [dbo].[JuryLogs] CHECK CONSTRAINT [FK_JuryLogs_AdditionalVotings_AdditionalVotingId]
GO
ALTER TABLE [dbo].[JuryLogs] WITH CHECK ADD CONSTRAINT [FK_JuryLogs_Plays_PlayId]
FOREIGN KEY([PlayId]) REFERENCES [dbo].[Plays] ([Id])
GO
ALTER TABLE [dbo].[JuryLogs] CHECK CONSTRAINT [FK_JuryLogs_Plays_PlayId]
GO
ALTER TABLE [dbo].[JuryLogs] WITH CHECK ADD CONSTRAINT [FK_JuryLogs_Users_JuryId]
FOREIGN KEY([JuryId]) REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[JuryLogs] CHECK CONSTRAINT [FK_JuryLogs_Users_JuryId]
GO
ALTER TABLE [dbo].[JuryVotes]  WITH CHECK ADD  CONSTRAINT [FK_JuryVotes_PlayAwardCategories] FOREIGN KEY([PlayAwardCategoryId])
REFERENCES [dbo].[PlayAwardCategories] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryVotes] CHECK CONSTRAINT [FK_JuryVotes_PlayAwardCategories]
GO
ALTER TABLE [dbo].[JuryVotes]  WITH CHECK ADD  CONSTRAINT [FK_JuryVotes_Users] FOREIGN KEY([JuryId])
REFERENCES [dbo].[Users] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[JuryVotes] CHECK CONSTRAINT [FK_JuryVotes_Users]
GO
ALTER TABLE [dbo].[PlayAwardCategories]  WITH CHECK ADD  CONSTRAINT [FK_PlayAwardCategories_AwardCategories] FOREIGN KEY([AwardCategoryCode])
REFERENCES [dbo].[AwardCategories] ([CategoryCode])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[PlayAwardCategories] CHECK CONSTRAINT [FK_PlayAwardCategories_AwardCategories]
GO
ALTER TABLE [dbo].[PlayAwardCategories]  WITH CHECK ADD  CONSTRAINT [FK_PlayAwardCategories_Images_PhotoImageId] FOREIGN KEY([PhotoImageId])
REFERENCES [dbo].[Images] ([Id])
GO
ALTER TABLE [dbo].[PlayAwardCategories] CHECK CONSTRAINT [FK_PlayAwardCategories_Images_PhotoImageId]
GO
ALTER TABLE [dbo].[PlayAwardCategories]  WITH CHECK ADD  CONSTRAINT [FK_PlayAwardCategories_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[PlayAwardCategories] CHECK CONSTRAINT [FK_PlayAwardCategories_Plays]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [FK_Plays_Form_SourceFormId] FOREIGN KEY([SourceFormId])
REFERENCES [dbo].[Form] ([Id])
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [FK_Plays_Form_SourceFormId]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [FK_Plays_PlayStatuses] FOREIGN KEY([StatusCode])
REFERENCES [dbo].[PlayStatuses] ([StatusCode])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [FK_Plays_PlayStatuses]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [FK_Rankings_PlayAwardCategories] FOREIGN KEY([PlayAwardCategoryId])
REFERENCES [dbo].[PlayAwardCategories] ([Id])
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [FK_Rankings_PlayAwardCategories]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [FK_Rankings_Plays] FOREIGN KEY([PlayId])
REFERENCES [dbo].[Plays] ([Id])
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [FK_Rankings_Plays]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_Users_Group] FOREIGN KEY([GroupCode])
REFERENCES [dbo].[Group] ([Code])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_Users_Group]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_Users_Images_PhotoImageId] FOREIGN KEY([PhotoImageId])
REFERENCES [dbo].[Images] ([Id])
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_Users_Images_PhotoImageId]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles] FOREIGN KEY([RoleCode])
REFERENCES [dbo].[Roles] ([RoleCode])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_Users_Roles]
GO
ALTER TABLE [dbo].[Users] WITH CHECK ADD CONSTRAINT [CK_Users_JuryPresident]
CHECK ([IsJuryPresident] = 0 OR ([RoleCode] = 2 AND [IsActive] = 1))
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [CK_Users_JuryPresident]
GO
ALTER TABLE [dbo].[UsersLog]  WITH CHECK ADD  CONSTRAINT [FK_UsersLog_Users_UserId] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON UPDATE NO ACTION
GO
ALTER TABLE [dbo].[UsersLog] CHECK CONSTRAINT [FK_UsersLog_Users_UserId]
GO
ALTER TABLE [dbo].[AdditionalVotings]  WITH CHECK ADD  CONSTRAINT [CK_AdditionalVotings_DateRange] CHECK  (([StartDate]<[EndDate]))
GO
ALTER TABLE [dbo].[AdditionalVotings] CHECK CONSTRAINT [CK_AdditionalVotings_DateRange]
GO
ALTER TABLE [dbo].[AdditionalVotingUsages]  WITH CHECK ADD  CONSTRAINT [CK_AdditionalVotingUsages_UsageType] CHECK  (([UsageType]=(1) OR [UsageType]=(0)))
GO
ALTER TABLE [dbo].[AdditionalVotingUsages] CHECK CONSTRAINT [CK_AdditionalVotingUsages_UsageType]
GO
ALTER TABLE [dbo].[JuryVotes] WITH CHECK ADD CONSTRAINT [CK_JuryVotes_Score] CHECK (([Score]>=(1) AND [Score]<=(10)))
GO
ALTER TABLE [dbo].[JuryVotes] CHECK CONSTRAINT [CK_JuryVotes_Score]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [CK_Plays_AdminRecord_StatusCode] CHECK  (([RecordType]=(0) OR [StatusCode]<>(1)))
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [CK_Plays_AdminRecord_StatusCode]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [CK_Plays_AdminRecord_StatusesDisabled] CHECK  (([RecordType]=(0) OR [JuriOylamaStatus]=(0) AND [KunyeGirisStatus]=(0)))
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [CK_Plays_AdminRecord_StatusesDisabled]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [CK_Plays_KunyeMustRemainPublished] CHECK  (([RecordType]=(1) OR [IsPublished]=(1)))
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [CK_Plays_KunyeMustRemainPublished]
GO
ALTER TABLE [dbo].[Plays]  WITH CHECK ADD  CONSTRAINT [CK_Plays_SourceFormRequiresKunye] CHECK  (([SourceFormId] IS NULL OR [RecordType]=(0)))
GO
ALTER TABLE [dbo].[Plays] CHECK CONSTRAINT [CK_Plays_SourceFormRequiresKunye]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [CK_Rankings_ArithmeticRank] CHECK  (([ArithmeticRank] IS NULL OR [ArithmeticRank]>(0)))
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [CK_Rankings_ArithmeticRank]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [CK_Rankings_ConfidenceValue] CHECK  (([ConfidenceValue] IS NULL OR [ConfidenceValue]>=(1) AND [ConfidenceValue]<=(4)))
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [CK_Rankings_ConfidenceValue]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [CK_Rankings_NumberOfActiveVote] CHECK  (([NumberOfActiveVote]>=(0)))
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [CK_Rankings_NumberOfActiveVote]
GO
ALTER TABLE [dbo].[Rankings]  WITH CHECK ADD  CONSTRAINT [CK_Rankings_TrimmedRank] CHECK  (([TrimmedRank] IS NULL OR [TrimmedRank]>(0)))
GO
ALTER TABLE [dbo].[Rankings] CHECK CONSTRAINT [CK_Rankings_TrimmedRank]
GO
ALTER TABLE [dbo].[Seasons]  WITH CHECK ADD  CONSTRAINT [CK_Seasons_KunyeRegistrationDateRange] CHECK  (([KunyeRegistrationStartDate]>=[SeasonStartDate] AND [KunyeRegistrationStartDate]<[KunyeRegistrationEndDate] AND [KunyeRegistrationEndDate]<=[SeasonEndDate]))
GO
ALTER TABLE [dbo].[Seasons] CHECK CONSTRAINT [CK_Seasons_KunyeRegistrationDateRange]
GO
ALTER TABLE [dbo].[Seasons]  WITH CHECK ADD  CONSTRAINT [CK_Seasons_NonNegativeCounts] CHECK  (([PlayCount]>=(0) AND [ActivePlayCount]>=(0) AND [VoteCount]>=(0)))
GO
ALTER TABLE [dbo].[Seasons] CHECK CONSTRAINT [CK_Seasons_NonNegativeCounts]
GO
ALTER TABLE [dbo].[Seasons]  WITH CHECK ADD  CONSTRAINT [CK_Seasons_SeasonDateRange] CHECK  (([SeasonStartDate]<[SeasonEndDate]))
GO
ALTER TABLE [dbo].[Seasons] CHECK CONSTRAINT [CK_Seasons_SeasonDateRange]
GO
ALTER TABLE [dbo].[Seasons]  WITH CHECK ADD  CONSTRAINT [CK_Seasons_VotingDateRange] CHECK  (([VotingStartDate]>=[SeasonStartDate] AND [VotingStartDate]<[VotingEndDate] AND [VotingEndDate]<=[SeasonEndDate]))
GO
ALTER TABLE [dbo].[Seasons] CHECK CONSTRAINT [CK_Seasons_VotingDateRange]
GO
