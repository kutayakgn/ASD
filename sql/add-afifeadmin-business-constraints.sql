USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- These code columns are referenced by foreign keys and must be unique.
    IF OBJECT_ID(N'[dbo].[UQ_AwardCategories_CategoryCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[AwardCategories]
            ADD CONSTRAINT [UQ_AwardCategories_CategoryCode]
            UNIQUE ([CategoryCode]);

    IF OBJECT_ID(N'[dbo].[UQ_Group_Code]', N'UQ') IS NULL
        ALTER TABLE [dbo].[Group]
            ADD CONSTRAINT [UQ_Group_Code]
            UNIQUE ([Code]);

    IF OBJECT_ID(N'[dbo].[UQ_PlayStatuses_StatusCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[PlayStatuses]
            ADD CONSTRAINT [UQ_PlayStatuses_StatusCode]
            UNIQUE ([StatusCode]);

    IF OBJECT_ID(N'[dbo].[UQ_Roles_RoleCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[Roles]
            ADD CONSTRAINT [UQ_Roles_RoleCode]
            UNIQUE ([RoleCode]);

    -- A play can be assigned to the same jury member only once.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[JuryAssignedPlays]')
          AND [name] = N'UX_JuryAssignedPlays_PlayId_JuryId'
    )
        CREATE UNIQUE INDEX [UX_JuryAssignedPlays_PlayId_JuryId]
            ON [dbo].[JuryAssignedPlays] ([PlayId], [JuryId])
            WHERE [IsPublished] = 1;

    -- A ticket fee can be entered once per user and play.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[JuryGameTicketFees]')
          AND [name] = N'UX_JuryGameTicketFees_UserId_PlayId'
    )
        CREATE UNIQUE INDEX [UX_JuryGameTicketFees_UserId_PlayId]
            ON [dbo].[JuryGameTicketFees] ([UserId], [PlayId])
            WHERE [IsPublished] = 1;

    -- A jury member can vote once for the same play award category record.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[JuryVotes]')
          AND [name] = N'UX_JuryVotes_JuryId_PlayAwardCategoryId'
    )
        CREATE UNIQUE INDEX [UX_JuryVotes_JuryId_PlayAwardCategoryId]
            ON [dbo].[JuryVotes] ([JuryId], [PlayAwardCategoryId])
            WHERE [IsPublished] = 1;

    -- The same candidate cannot be entered twice for a play/category/role.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[PlayAwardCategories]')
          AND [name] = N'UX_PlayAwardCategories_Play_Category_Role_Candidate'
    )
        CREATE UNIQUE INDEX [UX_PlayAwardCategories_Play_Category_Role_Candidate]
            ON [dbo].[PlayAwardCategories]
               ([PlayId], [AwardCategoryCode], [RoleCode], [Candidate])
            WHERE [IsPublished] = 1;

    -- Only one current record is allowed for each play/category/role.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE [object_id] = OBJECT_ID(N'[dbo].[PlayAwardCategories]')
          AND [name] = N'UX_PlayAwardCategories_Current_Play_Category_Role'
    )
        CREATE UNIQUE INDEX [UX_PlayAwardCategories_Current_Play_Category_Role]
            ON [dbo].[PlayAwardCategories]
               ([PlayId], [AwardCategoryCode], [RoleCode], [IsCurrent])
            WHERE [IsCurrent] = 1 AND [IsPublished] = 1;

    -- RecordType 0 represents Kunye giris, 1 represents Admin giris.
    IF COL_LENGTH(N'[dbo].[Plays]', N'RecordType') IS NULL
    BEGIN
        ALTER TABLE [dbo].[Plays]
            ADD [RecordType] [bit] NOT NULL
                CONSTRAINT [DF_Plays_RecordType] DEFAULT (0) WITH VALUES;
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
