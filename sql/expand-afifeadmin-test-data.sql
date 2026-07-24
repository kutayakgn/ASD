USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @CoordinatorUserId uniqueidentifier = '50000000-0000-0000-0000-000000000001';

    DECLARE @Rows TABLE
    (
        N int NOT NULL PRIMARY KEY,
        PlayNo int NOT NULL,
        JuryNo int NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        JuryId uniqueidentifier NOT NULL,
        PlayAwardCategoryId uniqueidentifier NOT NULL,
        AssignmentId uniqueidentifier NOT NULL,
        TicketFeeId uniqueidentifier NOT NULL,
        VoteId uniqueidentifier NOT NULL
    );

    INSERT INTO @Rows
    SELECT
        n.N,
        calc.PlayNo,
        calc.JuryNo,
        CONVERT(uniqueidentifier, '60000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), calc.PlayNo), 12)),
        CONVERT(uniqueidentifier, '50000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), calc.JuryNo), 12)),
        CONVERT(uniqueidentifier, '70000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '80000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, '90000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12)),
        CONVERT(uniqueidentifier, 'a0000000-0000-0000-0000-' + RIGHT('000000000000' + CONVERT(varchar(12), n.N), 12))
    FROM
    (
        VALUES
            (11),(12),(13),(14),(15),(16),(17),(18),(19),(20),
            (21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
            (31),(32),(33),(34),(35),(36),(37),(38),(39),(40)
    ) AS n(N)
    CROSS APPLY
    (
        SELECT
            ((n.N - 11) % 10) + 1 AS PlayNo,
            2 + (((((n.N - 11) % 10) + 1) + ((n.N - 11) / 10)) % 9) AS JuryNo
    ) AS calc;

    -- Add 30 historical candidates without creating a second current record.
    INSERT INTO [dbo].[PlayAwardCategories]
        ([Id], [PlayId], [PhotoImageId], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy],
         [IsPublished], [Candidate], [AwardCategoryCode], [IsCurrent], [Role], [RoleCode])
    SELECT
        r.PlayAwardCategoryId,
        r.PlayId,
        NULL,
        DATEADD(minute, -r.N, @Now),
        @CoordinatorUserId,
        NULL,
        NULL,
        1,
        CONCAT(N'Ek Aday ', r.N),
        r.PlayNo,
        0,
        CASE WHEN r.N % 2 = 0 THEN N'Yardımcı Rol' ELSE N'Başrol' END,
        CASE WHEN r.N % 2 = 0 THEN 2 ELSE 1 END
    FROM @Rows AS r
    INNER JOIN [dbo].[Plays] AS p ON p.[Id] = r.PlayId
    INNER JOIN [dbo].[AwardCategories] AS ac ON ac.[CategoryCode] = r.PlayNo
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[PlayAwardCategories] AS pac
        WHERE pac.[Id] = r.PlayAwardCategoryId
           OR (pac.[PlayId] = r.PlayId
               AND pac.[AwardCategoryCode] = r.PlayNo
               AND pac.[RoleCode] = CASE WHEN r.N % 2 = 0 THEN 2 ELSE 1 END
               AND pac.[Candidate] = CONCAT(N'Ek Aday ', r.N))
    );

    -- Add 30 unique play/jury assignments.
    INSERT INTO [dbo].[JuryAssignedPlays]
        ([Id], [PlayId], [CreatedAt], [CreatedBy], [UpdatedAt], [UpdatedBy], [IsPublished], [JuryId])
    SELECT
        r.AssignmentId, r.PlayId, DATEADD(minute, -r.N, @Now),
        @CoordinatorUserId, NULL, NULL, 1, r.JuryId
    FROM @Rows AS r
    INNER JOIN [dbo].[Plays] AS p ON p.[Id] = r.PlayId
    INNER JOIN [dbo].[Users] AS u ON u.[Id] = r.JuryId AND u.[RoleCode] = 2
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[JuryAssignedPlays] AS jap
        WHERE jap.[Id] = r.AssignmentId
           OR (jap.[PlayId] = r.PlayId AND jap.[JuryId] = r.JuryId)
    );

    -- Add 30 unique fee records for the same play/jury combinations.
    INSERT INTO [dbo].[JuryGameTicketFees]
        ([Id], [UserId], [PlayId], [TicketFee], [CreatedAt], [CreatedBy],
         [UpdatedAt], [UpdatedBy], [IsPublished])
    SELECT
        r.TicketFeeId, r.JuryId, r.PlayId,
        CONVERT(decimal(10, 2), 150 + (r.N * 7.5)),
        DATEADD(minute, -r.N, @Now), @CoordinatorUserId, NULL, NULL, 1
    FROM @Rows AS r
    INNER JOIN [dbo].[Plays] AS p ON p.[Id] = r.PlayId
    INNER JOIN [dbo].[Users] AS u ON u.[Id] = r.JuryId AND u.[RoleCode] = 2
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[JuryGameTicketFees] AS fee
        WHERE fee.[Id] = r.TicketFeeId
           OR (fee.[UserId] = r.JuryId AND fee.[PlayId] = r.PlayId)
    );

    -- Add one vote for each newly created candidate and jury combination.
    INSERT INTO [dbo].[JuryVotes]
        ([Id], [PlayAwardCategoryId], [CreatedAt], [CreatedBy], [UpdatedAt],
         [UpdatedBy], [IsPublished], [Score], [JuryId])
    SELECT
        r.VoteId, r.PlayAwardCategoryId, DATEADD(minute, -r.N, @Now),
        r.JuryId, NULL, NULL, 1, ((r.N - 1) % 10) + 1, r.JuryId
    FROM @Rows AS r
    INNER JOIN [dbo].[PlayAwardCategories] AS pac ON pac.[Id] = r.PlayAwardCategoryId
    INNER JOIN [dbo].[Users] AS u ON u.[Id] = r.JuryId AND u.[RoleCode] = 2
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[JuryVotes] AS vote
        WHERE vote.[Id] = r.VoteId
           OR (vote.[JuryId] = r.JuryId
               AND vote.[PlayAwardCategoryId] = r.PlayAwardCategoryId)
    );

    -- Form JSON formats:
    -- Display: JSON array, actor fields: JSON object, design fields: JSON array.
    UPDATE f
    SET
        f.[Display] = CONCAT(
            N'[{"Location":"Afife Tiyatro Sahnesi ', formData.N,
            N'","Date":"', CONVERT(char(10), DATEADD(day, formData.N - 1, CONVERT(date, '2025-11-08')), 103),
            N'","Time":"', RIGHT('0' + CONVERT(varchar(2), 18 + (formData.N % 5)), 2),
            N':', RIGHT('0' + CONVERT(varchar(2), (formData.N * 5) % 60), 2), N'"}]'),
        f.[LeadActress] = CONCAT(
            N'{"Name":"Başrol Kadın Oyuncu ', formData.N,
            N'","Role":"Başrol","ImageUrl":"basrol-kadin-', formData.N,
            N'.jpg","Base64":"data:image/jpeg;base64,dGVzdC1rYWRpbi0=', formData.N, N'"}'),
        f.[LeadActor] = CONCAT(
            N'{"Name":"Başrol Erkek Oyuncu ', formData.N,
            N'","Role":"Başrol","ImageUrl":"basrol-erkek-', formData.N,
            N'.jpg","Base64":"data:image/jpeg;base64,dGVzdC1lcmtlay0=', formData.N, N'"}'),
        f.[SupportActress] = CONCAT(
            N'{"Name":"Yardımcı Kadın Oyuncu ', formData.N,
            N'","Role":"Yardımcı Rol","ImageUrl":"yardimci-kadin-', formData.N,
            N'.jpg","Base64":"data:image/jpeg;base64,eWFyZGltY2kta2FkaW4=', formData.N, N'"}'),
        f.[SupportActor] = CONCAT(
            N'{"Name":"Yardımcı Erkek Oyuncu ', formData.N,
            N'","Role":"Yardımcı Rol","ImageUrl":"yardimci-erkek-', formData.N,
            N'.jpg","Base64":"data:image/jpeg;base64,eWFyZGltY2ktZXJrZWs=', formData.N, N'"}'),
        f.[StageDesign] = CONCAT(N'[{"Name":"Sahne Tasarımcısı ', formData.N, N'"}]'),
        f.[ClothesDesign] = CONCAT(N'[{"Name":"Giysi Tasarımcısı ', formData.N, N'"}]'),
        f.[LightDesign] = CONCAT(N'[{"Name":"Işık Tasarımcısı ', formData.N, N'"}]'),
        f.[StageMusic] = CONCAT(N'[{"Name":"Sahne Müziği Bestecisi ', formData.N, N'"}]'),
        f.[Choreography] = CONCAT(N'[{"Name":"Koreograf ', formData.N, N'"}]'),
        f.[UpdatedDate] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[Form] AS f
    CROSS APPLY
    (
        SELECT TRY_CONVERT(int, RIGHT(f.[ApplicationNumber], 5)) AS N
    ) AS formData
    WHERE f.[ApplicationNumber] LIKE 'T[0-9][0-9][0-9][0-9][0-9]'
      AND formData.N BETWEEN 1 AND 10;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT N'PlayAwardCategories' AS [TableName], COUNT(*) AS [RowCount]
FROM [dbo].[PlayAwardCategories]
UNION ALL
SELECT N'JuryAssignedPlays', COUNT(*) FROM [dbo].[JuryAssignedPlays]
UNION ALL
SELECT N'JuryGameTicketFees', COUNT(*) FROM [dbo].[JuryGameTicketFees]
UNION ALL
SELECT N'JuryVotes', COUNT(*) FROM [dbo].[JuryVotes];

SELECT
    [ApplicationNumber],
    ISJSON([Display]) AS [DisplayIsJson],
    ISJSON([LeadActress]) AS [LeadActressIsJson],
    ISJSON([LeadActor]) AS [LeadActorIsJson],
    ISJSON([SupportActress]) AS [SupportActressIsJson],
    ISJSON([SupportActor]) AS [SupportActorIsJson],
    ISJSON([StageDesign]) AS [StageDesignIsJson],
    ISJSON([ClothesDesign]) AS [ClothesDesignIsJson],
    ISJSON([LightDesign]) AS [LightDesignIsJson],
    ISJSON([StageMusic]) AS [StageMusicIsJson],
    ISJSON([Choreography]) AS [ChoreographyIsJson]
FROM [dbo].[Form]
WHERE [ApplicationNumber] LIKE 'T[0-9][0-9][0-9][0-9][0-9]'
ORDER BY [ApplicationNumber];
GO
