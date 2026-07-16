USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Now datetime2(7) = SYSUTCDATETIME();
    DECLARE @CoordinatorId uniqueidentifier = '10000000-0000-0000-0000-000000000001';

    DECLARE @Seed TABLE
    (
        N int NOT NULL PRIMARY KEY,
        GroupId uniqueidentifier NOT NULL,
        StatusId uniqueidentifier NOT NULL,
        CategoryId uniqueidentifier NOT NULL,
        UserId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        PlayAwardCategoryId uniqueidentifier NOT NULL,
        AssignmentId uniqueidentifier NOT NULL,
        TicketFeeId uniqueidentifier NOT NULL,
        VoteId uniqueidentifier NOT NULL,
        AnnouncementId uniqueidentifier NOT NULL,
        ConfigId uniqueidentifier NOT NULL,
        ImageId uniqueidentifier NOT NULL
    );

    INSERT INTO @Seed
    SELECT
        n.N,
        CONVERT(uniqueidentifier, '20000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '30000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '40000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '50000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '60000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '70000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '80000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '90000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, 'a0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, 'b0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, 'c0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, 'd0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12))
    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) AS n(N);

    -- The two application roles requested for the shared database.
    UPDATE [dbo].[Roles]
    SET [RoleName] = N'Coordinator', [IsPublished] = 1, [UpdatedAt] = @Now
    WHERE [RoleCode] = 1;

    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[Roles]
            ([Id], [RoleName], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [RoleCode])
        VALUES
            (@CoordinatorId, N'Coordinator', @Now, NULL, NULL, NULL, 1, 1);

    UPDATE [dbo].[Roles]
    SET [RoleName] = N'Jury', [IsPublished] = 1, [UpdatedAt] = @Now
    WHERE [RoleCode] = 2;

    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[Roles]
            ([Id], [RoleName], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [RoleCode])
        VALUES
            ('10000000-0000-0000-0000-000000000002', N'Jury', @Now, NULL, NULL, NULL, 1, 2);

    INSERT INTO [dbo].[Group]
        ([Id], [Code], [GroupName], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT s.GroupId, s.N, CONCAT(N'Test Group ', s.N), @Now, NULL, NULL, NULL, 1
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Group] AS g WHERE g.[Id] = s.GroupId OR g.[Code] = s.N);

    INSERT INTO [dbo].[PlayStatuses]
        ([Id], [StatusName], [StatusCode], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [StatusColor])
    SELECT s.StatusId, CONCAT(N'Test Status ', s.N), s.N, @Now, NULL, NULL, NULL, 1,
           CONCAT(N'#', RIGHT('00000' + CONVERT(varchar(6), s.N * 111111), 6))
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[PlayStatuses] AS ps WHERE ps.[Id] = s.StatusId OR ps.[StatusCode] = s.N);

    INSERT INTO [dbo].[AwardCategories]
        ([Id], [CategoryName], [CategoryCode], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT s.CategoryId, CONCAT(N'Test Award Category ', s.N), s.N, @Now, NULL, NULL, NULL, 1
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[AwardCategories] AS ac WHERE ac.[Id] = s.CategoryId OR ac.[CategoryCode] = s.N);

    INSERT INTO [dbo].[Users]
        ([Id], [FirstName], [LastName], [Phone], [Photo], [Username], [PasswordHash], [Email],
         [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [RoleCode], [GroupCode])
    SELECT
        s.UserId,
        CASE WHEN s.N = 1 THEN N'Test Coordinator' ELSE CONCAT(N'Test Jury ', s.N - 1) END,
        N'User',
        CONCAT(N'555000', RIGHT('0000' + CONVERT(varchar(4), s.N), 4)),
        NULL,
        CASE WHEN s.N = 1 THEN N'coordinator.test' ELSE CONCAT(N'jury.test', s.N - 1) END,
        CONVERT(nvarchar(500), HASHBYTES('SHA2_256', N'Test123!'), 2),
        CASE WHEN s.N = 1 THEN N'coordinator.test@afife.local' ELSE CONCAT(N'jury.test', s.N - 1, N'@afife.local') END,
        @Now,
        NULL,
        NULL,
        NULL,
        1,
        CASE WHEN s.N = 1 THEN 1 ELSE 2 END,
        s.N
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Users] AS u WHERE u.[Id] = s.UserId);

    INSERT INTO [dbo].[Plays]
        ([Id], [PlayName], [StatusCode], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy],
         [IsPublished], [Slug], [TheaterName], [Phone], [ContactPersonName], [ContactPersonPhone],
         [Address], [Email], [FromKunye])
    SELECT
        s.PlayId,
        CONCAT(N'Test Play ', s.N),
        s.N,
        DATEADD(day, -s.N, @Now),
        @CoordinatorId,
        NULL,
        NULL,
        1,
        CONCAT('test-play-', s.N),
        CONCAT('Test Theater ', s.N),
        CONCAT('0212000', RIGHT('0000' + CONVERT(varchar(4), s.N), 4)),
        CONCAT('Contact ', s.N),
        CONCAT('0532000', RIGHT('0000' + CONVERT(varchar(4), s.N), 4)),
        CONCAT('Test Address ', s.N),
        CONCAT('play', s.N, '@afife.local'),
        CASE WHEN s.N % 2 = 0 THEN 1 ELSE 0 END
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Plays] AS p WHERE p.[Id] = s.PlayId);

    INSERT INTO [dbo].[PlayAwardCategories]
        ([Id], [PlayId], [Photo], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished],
         [Candidate], [AwardCategoryCode], [IsCurrent], [Role], [RoleCode], [IsOld])
    SELECT
        s.PlayAwardCategoryId,
        s.PlayId,
        NULL,
        @Now,
        @CoordinatorId,
        NULL,
        NULL,
        1,
        CONCAT(N'Test Candidate ', s.N),
        s.N,
        1,
        CASE WHEN s.N % 2 = 0 THEN N'Supporting Role' ELSE N'Lead Role' END,
        CASE WHEN s.N % 2 = 0 THEN 2 ELSE 1 END,
        0
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[PlayAwardCategories] AS pac WHERE pac.[Id] = s.PlayAwardCategoryId);

    INSERT INTO [dbo].[JuryAssignedPlays]
        ([Id], [PlayId], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [JuryId])
    SELECT
        s.AssignmentId,
        s.PlayId,
        @Now,
        @CoordinatorId,
        NULL,
        NULL,
        1,
        jury.UserId
    FROM @Seed AS s
    INNER JOIN @Seed AS jury ON jury.N = CASE WHEN s.N = 10 THEN 2 ELSE s.N + 1 END
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[JuryAssignedPlays] AS jap WHERE jap.[Id] = s.AssignmentId);

    INSERT INTO [dbo].[JuryGameTicketFees]
        ([Id], [UserId], [PlayId], [TicketFee], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT
        s.TicketFeeId,
        jury.UserId,
        s.PlayId,
        CONVERT(decimal(10, 2), 100 + (s.N * 25)),
        @Now,
        @CoordinatorId,
        NULL,
        NULL,
        1
    FROM @Seed AS s
    INNER JOIN @Seed AS jury ON jury.N = CASE WHEN s.N = 10 THEN 2 ELSE s.N + 1 END
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[JuryGameTicketFees] AS f WHERE f.[Id] = s.TicketFeeId);

    INSERT INTO [dbo].[JuryVotes]
        ([Id], [PlayAwardCategoryId], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy],
         [IsPublished], [Score], [JuryId])
    SELECT
        s.VoteId,
        s.PlayAwardCategoryId,
        @Now,
        jury.UserId,
        NULL,
        NULL,
        1,
        ((s.N - 1) % 10) + 1,
        jury.UserId
    FROM @Seed AS s
    INNER JOIN @Seed AS jury ON jury.N = CASE WHEN s.N = 10 THEN 2 ELSE s.N + 1 END
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[JuryVotes] AS v WHERE v.[Id] = s.VoteId);

    INSERT INTO [dbo].[Announcements]
        ([Id], [AnnouncementLocationId], [Text], [ButtonText], [ButtonLink], [Image], [BackgroundImage],
         [BackgroundColor], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT
        s.AnnouncementId, s.N, CONCAT(N'Test announcement ', s.N), N'Details',
        CONCAT(N'/announcements/test-', s.N), NULL, NULL, N'#F5F1E8', @Now,
        @CoordinatorId, NULL, NULL, 1
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Announcements] AS a WHERE a.[Id] = s.AnnouncementId);

    INSERT INTO [dbo].[Configs]
        ([id], [ConfigName], [ConfigValue], [created_at], [created_by], [updated_at], [updated_by])
    SELECT
        s.ConfigId, CONCAT(N'TestConfig', s.N), CONCAT(N'TestValue', s.N),
        @Now, @CoordinatorId, @Now, NULL
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Configs] AS c WHERE c.[id] = s.ConfigId);

    INSERT INTO [dbo].[Images]
        ([Id], [FileName], [ContentType], [ImageData], [CreatedAt], [UpdatedAt],
         [CreatedBy], [UpdatedBy], [IsPublished])
    SELECT
        s.ImageId, CONCAT(N'test-image-', s.N, N'.txt'), N'text/plain',
        CONVERT(varbinary(max), CONCAT('test-image-data-', s.N)), @Now, NULL,
        @CoordinatorId, NULL, 1
    FROM @Seed AS s
    WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Images] AS i WHERE i.[Id] = s.ImageId);

    INSERT INTO [dbo].[Form]
        ([ApplicationNumber], [SeasonId], [CreatedDate], [UpdatedDate], [RepertoireName], [TheatreName],
         [PremiereDate], [Display], [ApplicantName], [ApplicantRole], [Phone], [Email], [Director],
         [ContactName], [ContactPhone], [LeadActress], [LeadActor], [SupportActress], [SupportActor],
         [StageDesign], [ClothesDesign], [LightDesign], [StageMusic], [Choreography], [Active], [Deleted])
    SELECT
        CONCAT('T', RIGHT('00000' + CONVERT(varchar(5), s.N), 5)),
        2026,
        DATEADD(day, -s.N, @Now),
        NULL,
        CONCAT(N'Test Repertoire ', s.N),
        CONCAT(N'Test Theatre ', s.N),
        CONVERT(date, DATEADD(day, s.N, @Now)),
        CONCAT(N'Test display information ', s.N),
        CONCAT(N'Applicant ', s.N),
        N'Producer',
        CONCAT(N'555100', RIGHT('0000' + CONVERT(varchar(4), s.N), 4)),
        CONCAT(N'applicant', s.N, N'@afife.local'),
        CONCAT(N'Director ', s.N),
        CONCAT(N'Contact ', s.N),
        CONCAT(N'555200', RIGHT('0000' + CONVERT(varchar(4), s.N), 4)),
        CONCAT(N'Lead Actress ', s.N),
        CONCAT(N'Lead Actor ', s.N),
        CONCAT(N'Support Actress ', s.N),
        CONCAT(N'Support Actor ', s.N),
        CONCAT(N'Stage Designer ', s.N),
        CONCAT(N'Costume Designer ', s.N),
        CONCAT(N'Light Designer ', s.N),
        CONCAT(N'Composer ', s.N),
        CONCAT(N'Choreographer ', s.N),
        1,
        0
    FROM @Seed AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM [dbo].[Form] AS f
        WHERE f.[ApplicationNumber] = CONCAT('T', RIGHT('00000' + CONVERT(varchar(5), s.N), 5))
    );

    INSERT INTO [dbo].[Manager]
        ([FullName], [Email], [Password], [CreatedDate], [UpdatedDate])
    SELECT
        CONCAT(N'Test Manager ', s.N),
        CONCAT(N'manager', s.N, N'@afife.local'),
        N'Test123!',
        @Now,
        NULL
    FROM @Seed AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM [dbo].[Manager] AS m
        WHERE m.[Email] = CONCAT(N'manager', s.N, N'@afife.local')
    );

    INSERT INTO [dbo].[Log]
        ([Title], [Source], [EventType], [Message], [CreatedDate])
    SELECT
        CONCAT(N'Test Log ', s.N),
        N'SeedScript',
        CASE WHEN s.N % 2 = 0 THEN N'Information' ELSE N'Test' END,
        CONCAT(N'Test log message ', s.N),
        @Now
    FROM @Seed AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM [dbo].[Log] AS l
        WHERE l.[Title] = CONCAT(N'Test Log ', s.N) AND l.[Source] = N'SeedScript'
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT N'Roles' AS [TableName], COUNT(*) AS [RowCount] FROM [dbo].[Roles]
UNION ALL SELECT N'Groups', COUNT(*) FROM [dbo].[Group]
UNION ALL SELECT N'PlayStatuses', COUNT(*) FROM [dbo].[PlayStatuses]
UNION ALL SELECT N'AwardCategories', COUNT(*) FROM [dbo].[AwardCategories]
UNION ALL SELECT N'Users', COUNT(*) FROM [dbo].[Users]
UNION ALL SELECT N'Plays', COUNT(*) FROM [dbo].[Plays]
UNION ALL SELECT N'PlayAwardCategories', COUNT(*) FROM [dbo].[PlayAwardCategories]
UNION ALL SELECT N'JuryAssignedPlays', COUNT(*) FROM [dbo].[JuryAssignedPlays]
UNION ALL SELECT N'JuryGameTicketFees', COUNT(*) FROM [dbo].[JuryGameTicketFees]
UNION ALL SELECT N'JuryVotes', COUNT(*) FROM [dbo].[JuryVotes]
UNION ALL SELECT N'Announcements', COUNT(*) FROM [dbo].[Announcements]
UNION ALL SELECT N'Configs', COUNT(*) FROM [dbo].[Configs]
UNION ALL SELECT N'Images', COUNT(*) FROM [dbo].[Images]
UNION ALL SELECT N'Form', COUNT(*) FROM [dbo].[Form]
UNION ALL SELECT N'Manager', COUNT(*) FROM [dbo].[Manager]
UNION ALL SELECT N'Log', COUNT(*) FROM [dbo].[Log];
GO
