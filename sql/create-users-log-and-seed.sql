SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[dbo].[UsersLog]', N'U') IS NULL
    BEGIN
        CREATE TABLE [dbo].[UsersLog]
        (
            [Id] uniqueidentifier NOT NULL,
            [UserId] uniqueidentifier NULL,
            [ActorUserId] uniqueidentifier NULL,
            [Username] nvarchar(100) NOT NULL CONSTRAINT [DF_UsersLog_Username] DEFAULT (N''),
            [EventType] nvarchar(50) NOT NULL,
            [IsSuccessful] bit NOT NULL,
            [OccurredAt] datetime2(7) NOT NULL,
            [IpAddress] nvarchar(64) NULL,
            [UserAgent] nvarchar(1000) NULL,
            [Application] nvarchar(100) NOT NULL CONSTRAINT [DF_UsersLog_Application] DEFAULT (N'AfifeAdmin'),
            [Details] nvarchar(2000) NULL,
            [FailureReason] nvarchar(500) NULL,
            [OldValue] nvarchar(max) NULL,
            [NewValue] nvarchar(max) NULL,
            [CorrelationId] uniqueidentifier NOT NULL,
            [IsPublished] bit NOT NULL CONSTRAINT [DF_UsersLog_IsPublished] DEFAULT (1),
            CONSTRAINT [PK_UsersLog] PRIMARY KEY CLUSTERED ([Id])
        );
    END;

    IF OBJECT_ID(N'[dbo].[FK_UsersLog_Users_UserId]', N'F') IS NULL
    BEGIN
        ALTER TABLE [dbo].[UsersLog] WITH CHECK
            ADD CONSTRAINT [FK_UsersLog_Users_UserId]
            FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([Id])
            ON UPDATE CASCADE ON DELETE NO ACTION;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[UsersLog]')
          AND [name] = N'IX_UsersLog_UserId_EventType_OccurredAt'
    )
    BEGIN
        CREATE INDEX [IX_UsersLog_UserId_EventType_OccurredAt]
            ON [dbo].[UsersLog] ([UserId], [EventType], [OccurredAt] DESC)
            INCLUDE ([IsSuccessful], [IsPublished]);
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[UsersLog]')
          AND [name] = N'IX_UsersLog_Username_OccurredAt'
    )
    BEGIN
        CREATE INDEX [IX_UsersLog_Username_OccurredAt]
            ON [dbo].[UsersLog] ([Username], [OccurredAt] DESC);
    END;

    ;WITH ExistingUsers AS
    (
        SELECT
            [Id],
            [Username],
            ROW_NUMBER() OVER (ORDER BY CASE WHEN [RoleCode] = 2 THEN 0 ELSE 1 END, [CreatedAt], [Id]) AS [UserRow]
        FROM [dbo].[Users]
        WHERE [IsPublished] = 1
    ),
    UserCount AS
    (
        SELECT COUNT(*) AS [Total] FROM ExistingUsers
    ),
    Numbers AS
    (
        SELECT 1 AS [N]
        UNION ALL
        SELECT [N] + 1 FROM Numbers WHERE [N] < 30
    ),
    Seed AS
    (
        SELECT
            numbers.[N],
            users.[Id] AS [UserId],
            users.[Username],
            CASE numbers.[N] % 6
                WHEN 0 THEN N'PasswordChanged'
                WHEN 1 THEN N'LoginSucceeded'
                WHEN 2 THEN N'LoginFailed'
                WHEN 3 THEN N'Logout'
                WHEN 4 THEN N'LoginSucceeded'
                ELSE N'EmailChanged'
            END AS [EventType]
        FROM Numbers AS numbers
        CROSS JOIN UserCount AS counts
        INNER JOIN ExistingUsers AS users
            ON users.[UserRow] = ((numbers.[N] - 1) % NULLIF(counts.[Total], 0)) + 1
    )
    INSERT INTO [dbo].[UsersLog]
    (
        [Id], [UserId], [ActorUserId], [Username], [EventType], [IsSuccessful],
        [OccurredAt], [IpAddress], [UserAgent], [Application], [Details],
        [FailureReason], [OldValue], [NewValue], [CorrelationId], [IsPublished]
    )
    SELECT
        NEWID(),
        seed.[UserId],
        seed.[UserId],
        seed.[Username],
        seed.[EventType],
        CASE WHEN seed.[EventType] = N'LoginFailed' THEN 0 ELSE 1 END,
        DATEADD(hour, -seed.[N] * 7, SYSUTCDATETIME()),
        CONCAT(N'192.168.1.', (seed.[N] % 20) + 10),
        N'Mozilla/5.0 Afife test tarayıcısı',
        N'AfifeAdmin',
        CONCAT(N'TEST-SEED-', RIGHT(N'00' + CONVERT(nvarchar(2), seed.[N]), 2), N': Türkçe örnek kullanıcı işlemi.'),
        CASE WHEN seed.[EventType] = N'LoginFailed' THEN N'Hatalı kullanıcı adı veya şifre.' ELSE NULL END,
        CASE WHEN seed.[EventType] = N'EmailChanged' THEN CONCAT(N'eski-', seed.[Username], N'@afife.local') ELSE NULL END,
        CASE WHEN seed.[EventType] = N'EmailChanged' THEN CONCAT(seed.[Username], N'@afife.local') ELSE NULL END,
        NEWID(),
        1
    FROM Seed AS seed
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[UsersLog] AS existing
        WHERE existing.[Details] LIKE CONCAT(N'TEST-SEED-', RIGHT(N'00' + CONVERT(nvarchar(2), seed.[N]), 2), N':%')
    )
    OPTION (MAXRECURSION 30);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT [EventType], COUNT(*) AS [LogCount]
FROM [dbo].[UsersLog]
WHERE [IsPublished] = 1
GROUP BY [EventType]
ORDER BY [EventType];
