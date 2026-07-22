USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Code-based foreign keys require a unique candidate key on the parent table.
    IF OBJECT_ID(N'[dbo].[UQ_AwardCategories_CategoryCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[AwardCategories]
            ADD CONSTRAINT [UQ_AwardCategories_CategoryCode] UNIQUE ([CategoryCode]);

    IF OBJECT_ID(N'[dbo].[UQ_Group_Code]', N'UQ') IS NULL
        ALTER TABLE [dbo].[Group]
            ADD CONSTRAINT [UQ_Group_Code] UNIQUE ([Code]);

    IF OBJECT_ID(N'[dbo].[UQ_PlayStatuses_StatusCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[PlayStatuses]
            ADD CONSTRAINT [UQ_PlayStatuses_StatusCode] UNIQUE ([StatusCode]);

    IF OBJECT_ID(N'[dbo].[UQ_Roles_RoleCode]', N'UQ') IS NULL
        ALTER TABLE [dbo].[Roles]
            ADD CONSTRAINT [UQ_Roles_RoleCode] UNIQUE ([RoleCode]);

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_AwardCategories]', N'F') IS NULL
        ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
            ADD CONSTRAINT [FK_PlayAwardCategories_AwardCategories]
            FOREIGN KEY ([AwardCategoryCode])
            REFERENCES [dbo].[AwardCategories] ([CategoryCode]);

    IF OBJECT_ID(N'[dbo].[FK_Users_Group]', N'F') IS NULL
        ALTER TABLE [dbo].[Users] WITH CHECK
            ADD CONSTRAINT [FK_Users_Group]
            FOREIGN KEY ([GroupCode])
            REFERENCES [dbo].[Group] ([Code]);

    IF OBJECT_ID(N'[dbo].[FK_JuryAssignedPlays_Plays]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryAssignedPlays] WITH CHECK
            ADD CONSTRAINT [FK_JuryAssignedPlays_Plays]
            FOREIGN KEY ([PlayId])
            REFERENCES [dbo].[Plays] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_JuryAssignedPlays_Users]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryAssignedPlays] WITH CHECK
            ADD CONSTRAINT [FK_JuryAssignedPlays_Users]
            FOREIGN KEY ([JuryId])
            REFERENCES [dbo].[Users] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_JuryGameTicketFees_Users]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryGameTicketFees] WITH CHECK
            ADD CONSTRAINT [FK_JuryGameTicketFees_Users]
            FOREIGN KEY ([UserId])
            REFERENCES [dbo].[Users] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_JuryGameTicketFees_Plays]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryGameTicketFees] WITH CHECK
            ADD CONSTRAINT [FK_JuryGameTicketFees_Plays]
            FOREIGN KEY ([PlayId])
            REFERENCES [dbo].[Plays] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_JuryVotes_PlayAwardCategories]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryVotes] WITH CHECK
            ADD CONSTRAINT [FK_JuryVotes_PlayAwardCategories]
            FOREIGN KEY ([PlayAwardCategoryId])
            REFERENCES [dbo].[PlayAwardCategories] ([Id])
            ON UPDATE CASCADE
            ON DELETE CASCADE;

    IF OBJECT_ID(N'[dbo].[FK_JuryVotes_Users]', N'F') IS NULL
        ALTER TABLE [dbo].[JuryVotes] WITH CHECK
            ADD CONSTRAINT [FK_JuryVotes_Users]
            FOREIGN KEY ([JuryId])
            REFERENCES [dbo].[Users] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_Plays]', N'F') IS NULL
        ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
            ADD CONSTRAINT [FK_PlayAwardCategories_Plays]
            FOREIGN KEY ([PlayId])
            REFERENCES [dbo].[Plays] ([Id]);

    IF OBJECT_ID(N'[dbo].[FK_Plays_PlayStatuses]', N'F') IS NULL
        ALTER TABLE [dbo].[Plays] WITH CHECK
            ADD CONSTRAINT [FK_Plays_PlayStatuses]
            FOREIGN KEY ([StatusCode])
            REFERENCES [dbo].[PlayStatuses] ([StatusCode]);

    IF OBJECT_ID(N'[dbo].[FK_Users_Roles]', N'F') IS NULL
        ALTER TABLE [dbo].[Users] WITH CHECK
            ADD CONSTRAINT [FK_Users_Roles]
            FOREIGN KEY ([RoleCode])
            REFERENCES [dbo].[Roles] ([RoleCode]);

    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_ImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Announcements] WITH CHECK
            ADD CONSTRAINT [FK_Announcements_Images_ImageId]
            FOREIGN KEY ([ImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_Announcements_Images_BackgroundImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Announcements] WITH CHECK
            ADD CONSTRAINT [FK_Announcements_Images_BackgroundImageId]
            FOREIGN KEY ([BackgroundImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_Users_Images_PhotoImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[Users] WITH CHECK
            ADD CONSTRAINT [FK_Users_Images_PhotoImageId]
            FOREIGN KEY ([PhotoImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_Images_PhotoImageId]', N'F') IS NULL
        ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
            ADD CONSTRAINT [FK_PlayAwardCategories_Images_PhotoImageId]
            FOREIGN KEY ([PhotoImageId]) REFERENCES [dbo].[Images] ([Id])
            ON UPDATE NO ACTION ON DELETE NO ACTION;
    -- SQL Server does not automatically index foreign key columns.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Announcements]') AND name = N'IX_Announcements_ImageId')
        CREATE INDEX [IX_Announcements_ImageId] ON [dbo].[Announcements] ([ImageId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Announcements]') AND name = N'IX_Announcements_BackgroundImageId')
        CREATE INDEX [IX_Announcements_BackgroundImageId] ON [dbo].[Announcements] ([BackgroundImageId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Users_PhotoImageId')
        CREATE INDEX [IX_Users_PhotoImageId] ON [dbo].[Users] ([PhotoImageId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayAwardCategories]') AND name = N'IX_PlayAwardCategories_PhotoImageId')
        CREATE INDEX [IX_PlayAwardCategories_PhotoImageId] ON [dbo].[PlayAwardCategories] ([PhotoImageId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayAwardCategories]') AND name = N'IX_PlayAwardCategories_AwardCategoryCode')
        CREATE INDEX [IX_PlayAwardCategories_AwardCategoryCode]
            ON [dbo].[PlayAwardCategories] ([AwardCategoryCode]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayAwardCategories]') AND name = N'IX_PlayAwardCategories_PlayId')
        CREATE INDEX [IX_PlayAwardCategories_PlayId]
            ON [dbo].[PlayAwardCategories] ([PlayId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Users_GroupCode')
        CREATE INDEX [IX_Users_GroupCode] ON [dbo].[Users] ([GroupCode]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Users_RoleCode')
        CREATE INDEX [IX_Users_RoleCode] ON [dbo].[Users] ([RoleCode]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryAssignedPlays]') AND name = N'IX_JuryAssignedPlays_PlayId')
        CREATE INDEX [IX_JuryAssignedPlays_PlayId] ON [dbo].[JuryAssignedPlays] ([PlayId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryAssignedPlays]') AND name = N'IX_JuryAssignedPlays_JuryId')
        CREATE INDEX [IX_JuryAssignedPlays_JuryId] ON [dbo].[JuryAssignedPlays] ([JuryId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryGameTicketFees]') AND name = N'IX_JuryGameTicketFees_UserId')
        CREATE INDEX [IX_JuryGameTicketFees_UserId] ON [dbo].[JuryGameTicketFees] ([UserId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryGameTicketFees]') AND name = N'IX_JuryGameTicketFees_PlayId')
        CREATE INDEX [IX_JuryGameTicketFees_PlayId] ON [dbo].[JuryGameTicketFees] ([PlayId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryVotes]') AND name = N'IX_JuryVotes_PlayAwardCategoryId')
        CREATE INDEX [IX_JuryVotes_PlayAwardCategoryId] ON [dbo].[JuryVotes] ([PlayAwardCategoryId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[JuryVotes]') AND name = N'IX_JuryVotes_JuryId')
        CREATE INDEX [IX_JuryVotes_JuryId] ON [dbo].[JuryVotes] ([JuryId]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Plays]') AND name = N'IX_Plays_StatusCode')
        CREATE INDEX [IX_Plays_StatusCode] ON [dbo].[Plays] ([StatusCode]);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
