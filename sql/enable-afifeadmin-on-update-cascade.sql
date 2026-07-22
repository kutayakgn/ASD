USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- SQL Server requires foreign keys to be recreated to change referential actions.
    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_AwardCategories]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[PlayAwardCategories]
            DROP CONSTRAINT [FK_PlayAwardCategories_AwardCategories];

    IF OBJECT_ID(N'[dbo].[FK_Users_Group]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Users]
            DROP CONSTRAINT [FK_Users_Group];

    IF OBJECT_ID(N'[dbo].[FK_JuryAssignedPlays_Plays]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryAssignedPlays]
            DROP CONSTRAINT [FK_JuryAssignedPlays_Plays];

    IF OBJECT_ID(N'[dbo].[FK_JuryAssignedPlays_Users]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryAssignedPlays]
            DROP CONSTRAINT [FK_JuryAssignedPlays_Users];

    IF OBJECT_ID(N'[dbo].[FK_JuryGameTicketFees_Users]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryGameTicketFees]
            DROP CONSTRAINT [FK_JuryGameTicketFees_Users];

    IF OBJECT_ID(N'[dbo].[FK_JuryGameTicketFees_Plays]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryGameTicketFees]
            DROP CONSTRAINT [FK_JuryGameTicketFees_Plays];

    IF OBJECT_ID(N'[dbo].[FK_JuryVotes_PlayAwardCategories]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryVotes]
            DROP CONSTRAINT [FK_JuryVotes_PlayAwardCategories];

    IF OBJECT_ID(N'[dbo].[FK_JuryVotes_Users]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[JuryVotes]
            DROP CONSTRAINT [FK_JuryVotes_Users];

    IF OBJECT_ID(N'[dbo].[FK_PlayAwardCategories_Plays]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[PlayAwardCategories]
            DROP CONSTRAINT [FK_PlayAwardCategories_Plays];

    IF OBJECT_ID(N'[dbo].[FK_Plays_PlayStatuses]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Plays]
            DROP CONSTRAINT [FK_Plays_PlayStatuses];

    IF OBJECT_ID(N'[dbo].[FK_Users_Roles]', N'F') IS NOT NULL
        ALTER TABLE [dbo].[Users]
            DROP CONSTRAINT [FK_Users_Roles];

    ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
        ADD CONSTRAINT [FK_PlayAwardCategories_AwardCategories]
        FOREIGN KEY ([AwardCategoryCode])
        REFERENCES [dbo].[AwardCategories] ([CategoryCode])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[Users] WITH CHECK
        ADD CONSTRAINT [FK_Users_Group]
        FOREIGN KEY ([GroupCode])
        REFERENCES [dbo].[Group] ([Code])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[JuryAssignedPlays] WITH CHECK
        ADD CONSTRAINT [FK_JuryAssignedPlays_Plays]
        FOREIGN KEY ([PlayId])
        REFERENCES [dbo].[Plays] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[JuryAssignedPlays] WITH CHECK
        ADD CONSTRAINT [FK_JuryAssignedPlays_Users]
        FOREIGN KEY ([JuryId])
        REFERENCES [dbo].[Users] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[JuryGameTicketFees] WITH CHECK
        ADD CONSTRAINT [FK_JuryGameTicketFees_Users]
        FOREIGN KEY ([UserId])
        REFERENCES [dbo].[Users] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[JuryGameTicketFees] WITH CHECK
        ADD CONSTRAINT [FK_JuryGameTicketFees_Plays]
        FOREIGN KEY ([PlayId])
        REFERENCES [dbo].[Plays] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[JuryVotes] WITH CHECK
        ADD CONSTRAINT [FK_JuryVotes_PlayAwardCategories]
        FOREIGN KEY ([PlayAwardCategoryId])
        REFERENCES [dbo].[PlayAwardCategories] ([Id])
        ON UPDATE CASCADE
        ON DELETE CASCADE;

    ALTER TABLE [dbo].[JuryVotes] WITH CHECK
        ADD CONSTRAINT [FK_JuryVotes_Users]
        FOREIGN KEY ([JuryId])
        REFERENCES [dbo].[Users] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[PlayAwardCategories] WITH CHECK
        ADD CONSTRAINT [FK_PlayAwardCategories_Plays]
        FOREIGN KEY ([PlayId])
        REFERENCES [dbo].[Plays] ([Id])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[Plays] WITH CHECK
        ADD CONSTRAINT [FK_Plays_PlayStatuses]
        FOREIGN KEY ([StatusCode])
        REFERENCES [dbo].[PlayStatuses] ([StatusCode])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE [dbo].[Users] WITH CHECK
        ADD CONSTRAINT [FK_Users_Roles]
        FOREIGN KEY ([RoleCode])
        REFERENCES [dbo].[Roles] ([RoleCode])
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    fk.[name] AS [ForeignKey],
    OBJECT_SCHEMA_NAME(fk.[parent_object_id]) + N'.' + OBJECT_NAME(fk.[parent_object_id]) AS [ChildTable],
    fk.[update_referential_action_desc] AS [OnUpdate],
    fk.[delete_referential_action_desc] AS [OnDelete]
FROM sys.foreign_keys AS fk
WHERE fk.[name] IN
(
    N'FK_PlayAwardCategories_AwardCategories',
    N'FK_Users_Group',
    N'FK_JuryAssignedPlays_Plays',
    N'FK_JuryAssignedPlays_Users',
    N'FK_JuryGameTicketFees_Users',
    N'FK_JuryGameTicketFees_Plays',
    N'FK_JuryVotes_PlayAwardCategories',
    N'FK_JuryVotes_Users',
    N'FK_PlayAwardCategories_Plays',
    N'FK_Plays_PlayStatuses',
    N'FK_Users_Roles'
)
ORDER BY [ChildTable], [ForeignKey];
GO
