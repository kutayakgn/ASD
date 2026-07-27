USE [AfifeAdmin];
GO

/*
    Global soft-delete migration for AfifeAdmin.
    Run once against the AfifeAdmin database.

    Contract:
    - IsPublished = 1: visible, non-deleted row.
    - IsPublished = 0: soft-deleted row.
    - No FK physically cascades a delete.
    - Direct DELETE statements are converted to IsPublished = 0 updates.
*/
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.Configs', N'IsPublished') IS NULL
        ALTER TABLE dbo.Configs ADD IsPublished bit NOT NULL
            CONSTRAINT DF_Configs_IsPublished DEFAULT (1) WITH VALUES;

    IF COL_LENGTH(N'dbo.Form', N'IsPublished') IS NULL
        ALTER TABLE dbo.Form ADD IsPublished bit NOT NULL
            CONSTRAINT DF_Form_IsPublished DEFAULT (1) WITH VALUES;

    IF COL_LENGTH(N'dbo.Log', N'IsPublished') IS NULL
        ALTER TABLE dbo.[Log] ADD IsPublished bit NOT NULL
            CONSTRAINT DF_Log_IsPublished DEFAULT (1) WITH VALUES;

    IF COL_LENGTH(N'dbo.Manager', N'IsPublished') IS NULL
        ALTER TABLE dbo.[Manager] ADD IsPublished bit NOT NULL
            CONSTRAINT DF_Manager_IsPublished DEFAULT (1) WITH VALUES;

    /* Database-side defaults ensure omitted IsPublished values are inserted as 1. */
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Announcements') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Announcements ADD CONSTRAINT DF_Announcements_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.AwardCategories') AND c.name = N'IsPublished')
        ALTER TABLE dbo.AwardCategories ADD CONSTRAINT DF_AwardCategories_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Blacklist') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Blacklist ADD CONSTRAINT DF_Blacklist_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Configs') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Configs ADD CONSTRAINT DF_Configs_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Form') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Form ADD CONSTRAINT DF_Form_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.[Group]') AND c.name = N'IsPublished')
        ALTER TABLE dbo.[Group] ADD CONSTRAINT DF_Group_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Images') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Images ADD CONSTRAINT DF_Images_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.JuryAssignedPlays') AND c.name = N'IsPublished')
        ALTER TABLE dbo.JuryAssignedPlays ADD CONSTRAINT DF_JuryAssignedPlays_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.JuryGameTicketFees') AND c.name = N'IsPublished')
        ALTER TABLE dbo.JuryGameTicketFees ADD CONSTRAINT DF_JuryGameTicketFees_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.JuryVotes') AND c.name = N'IsPublished')
        ALTER TABLE dbo.JuryVotes ADD CONSTRAINT DF_JuryVotes_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.[Log]') AND c.name = N'IsPublished')
        ALTER TABLE dbo.[Log] ADD CONSTRAINT DF_Log_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.[Manager]') AND c.name = N'IsPublished')
        ALTER TABLE dbo.[Manager] ADD CONSTRAINT DF_Manager_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.PlayAwardCategories') AND c.name = N'IsPublished')
        ALTER TABLE dbo.PlayAwardCategories ADD CONSTRAINT DF_PlayAwardCategories_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Plays') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Plays ADD CONSTRAINT DF_Plays_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.PlayStatuses') AND c.name = N'IsPublished')
        ALTER TABLE dbo.PlayStatuses ADD CONSTRAINT DF_PlayStatuses_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Roles') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Roles ADD CONSTRAINT DF_Roles_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Users') AND c.name = N'IsPublished')
        ALTER TABLE dbo.Users ADD CONSTRAINT DF_Users_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'dbo.UsersLog') AND c.name = N'IsPublished')
        ALTER TABLE dbo.UsersLog ADD CONSTRAINT DF_UsersLog_IsPublished_SoftDelete DEFAULT (1) FOR IsPublished;
    IF EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.JuryVotes')
          AND referenced_object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
          AND name = N'FK_JuryVotes_PlayAwardCategories'
    )
    BEGIN
        ALTER TABLE dbo.JuryVotes
            DROP CONSTRAINT FK_JuryVotes_PlayAwardCategories;
    END;

    ALTER TABLE dbo.JuryVotes WITH CHECK
        ADD CONSTRAINT FK_JuryVotes_PlayAwardCategories
        FOREIGN KEY (PlayAwardCategoryId)
        REFERENCES dbo.PlayAwardCategories (Id)
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

    ALTER TABLE dbo.JuryVotes CHECK CONSTRAINT FK_JuryVotes_PlayAwardCategories;

    /* Keep vote history while allowing a new published vote for the same candidate. */
    IF EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.JuryVotes')
          AND name = N'UX_JuryVotes_JuryId_PlayAwardCategoryId'
    )
        DROP INDEX UX_JuryVotes_JuryId_PlayAwardCategoryId ON dbo.JuryVotes;

    ;WITH RankedVotes AS
    (
        SELECT
            vote.Id,
            ROW_NUMBER() OVER
            (
                PARTITION BY vote.JuryId, vote.PlayAwardCategoryId
                ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
            ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;

    CREATE UNIQUE INDEX UX_JuryVotes_JuryId_PlayAwardCategoryId
        ON dbo.JuryVotes (PlayAwardCategoryId, JuryId)
        WHERE IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JuryAssignedPlays') AND name = N'UX_JuryAssignedPlays_PlayId_JuryId')
        DROP INDEX UX_JuryAssignedPlays_PlayId_JuryId ON dbo.JuryAssignedPlays;
    CREATE UNIQUE INDEX UX_JuryAssignedPlays_PlayId_JuryId
        ON dbo.JuryAssignedPlays (PlayId, JuryId) WHERE IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JuryGameTicketFees') AND name = N'UX_JuryGameTicketFees_UserId_PlayId')
        DROP INDEX UX_JuryGameTicketFees_UserId_PlayId ON dbo.JuryGameTicketFees;
    CREATE UNIQUE INDEX UX_JuryGameTicketFees_UserId_PlayId
        ON dbo.JuryGameTicketFees (UserId, PlayId) WHERE IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories') AND name = N'UX_PlayAwardCategories_Play_Category_Role_Candidate')
        DROP INDEX UX_PlayAwardCategories_Play_Category_Role_Candidate ON dbo.PlayAwardCategories;
    CREATE UNIQUE INDEX UX_PlayAwardCategories_Play_Category_Role_Candidate
        ON dbo.PlayAwardCategories (PlayId, AwardCategoryCode, RoleCode, Candidate)
        WHERE IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories') AND name = N'UX_PlayAwardCategories_Current_Play_Category_Role')
        DROP INDEX UX_PlayAwardCategories_Current_Play_Category_Role ON dbo.PlayAwardCategories;
    CREATE UNIQUE INDEX UX_PlayAwardCategories_Current_Play_Category_Role
        ON dbo.PlayAwardCategories (PlayId, AwardCategoryCode, RoleCode, IsCurrent)
        WHERE IsCurrent = 1 AND IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Blacklist') AND name = N'UX_Blacklist_JuryId_PlayId_Published')
        DROP INDEX UX_Blacklist_JuryId_PlayId_Published ON dbo.Blacklist;
    CREATE UNIQUE INDEX UX_Blacklist_JuryId_PlayId_Published
        ON dbo.Blacklist (JuryId, PlayId) WHERE IsPublished = 1;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Admin_Username')
        DROP INDEX UX_Users_Admin_Username ON dbo.Users;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Admin_Email')
        DROP INDEX UX_Users_Admin_Email ON dbo.Users;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_RoleCode_Username_Published')
        DROP INDEX UX_Users_RoleCode_Username_Published ON dbo.Users;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_RoleCode_Email_Published')
        DROP INDEX UX_Users_RoleCode_Email_Published ON dbo.Users;

    IF EXISTS
    (
        SELECT 1 FROM dbo.Users
        WHERE IsPublished = 1
        GROUP BY RoleCode, Username
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51701, N'Published Users contain duplicate RoleCode + Username values.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.Users
        WHERE IsPublished = 1
        GROUP BY RoleCode, Email
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51702, N'Published Users contain duplicate RoleCode + Email values.', 1;

    CREATE UNIQUE INDEX UX_Users_RoleCode_Username_Published
        ON dbo.Users (RoleCode, Username) WHERE IsPublished = 1;
    CREATE UNIQUE INDEX UX_Users_RoleCode_Email_Published
        ON dbo.Users (RoleCode, Email) WHERE IsPublished = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* A new published vote soft-deletes every older vote in the same logical role. */
CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SingleRecordPerPlayCategoryRole
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedGroups TABLE
    (
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        RoleCode int NOT NULL,
        WinnerVoteId uniqueidentifier NOT NULL,
        PRIMARY KEY (JuryId, PlayId, AwardCategoryCode, RoleCode)
    );

    ;WITH ChangedVotes AS
    (
        SELECT
            changedVote.Id,
            changedVote.JuryId,
            candidate.PlayId,
            candidate.AwardCategoryCode,
            candidate.RoleCode,
            ROW_NUMBER() OVER
            (
                PARTITION BY changedVote.JuryId, candidate.PlayId,
                    candidate.AwardCategoryCode, candidate.RoleCode
                ORDER BY COALESCE(changedVote.UpdatedAt, changedVote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, changedVote.Id DESC
            ) AS VoteOrder
        FROM inserted AS changedVote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changedVote.PlayAwardCategoryId
        WHERE changedVote.IsPublished = 1
    )
    INSERT INTO @AffectedGroups
        (JuryId, PlayId, AwardCategoryCode, RoleCode, WinnerVoteId)
    SELECT JuryId, PlayId, AwardCategoryCode, RoleCode, Id
    FROM ChangedVotes
    WHERE VoteOrder = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN @AffectedGroups AS affected
        ON affected.JuryId = vote.JuryId
       AND affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode
    WHERE vote.Id <> affected.WinnerVoteId
      AND vote.IsPublished = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE (candidate.IsPublished = 0 AND vote.IsPublished = 1)
       OR (candidate.IsActive = 0 AND vote.IsActive = 1);
END;
GO

/* Candidate state changes preserve vote rows and synchronize their visibility/activity. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET vote.IsActive = candidate.IsActive,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsActive <> candidate.IsActive
          AND vote.IsPublished = 1
          AND vote.IsActive <> candidate.IsActive;
    END;

    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive
                ELSE 0
            END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR vote.IsActive <> CASE WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END
          );
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    ;WITH AffectedGroups AS
    (
        SELECT PlayId, AwardCategoryCode, RoleCode FROM inserted
        UNION
        SELECT PlayId, AwardCategoryCode, RoleCode FROM deleted
    ),
    RankedVotes AS
    (
        SELECT
            vote.Id,
            ROW_NUMBER() OVER
            (
                PARTITION BY vote.JuryId, candidate.PlayId,
                    candidate.AwardCategoryCode, candidate.RoleCode
                ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
            ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN AffectedGroups AS affected
            ON affected.PlayId = candidate.PlayId
           AND affected.AwardCategoryCode = candidate.AwardCategoryCode
           AND affected.RoleCode = candidate.RoleCode
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO
/* Direct SQL deletes are also soft deletes. */
CREATE OR ALTER TRIGGER dbo.TR_Announcements_SoftDelete ON dbo.Announcements INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Announcements target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_AwardCategories_SoftDelete ON dbo.AwardCategories INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.AwardCategories target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Blacklist_SoftDelete ON dbo.Blacklist INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Blacklist target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Configs_SoftDelete ON dbo.Configs INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Configs target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete ON dbo.Form INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Form target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Group_SoftDelete ON dbo.[Group] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Group] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Images_SoftDelete ON dbo.Images INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Images target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_SoftDelete ON dbo.JuryAssignedPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryAssignedPlays target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_SoftDelete ON dbo.JuryGameTicketFees INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryGameTicketFees target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SoftDelete ON dbo.JuryVotes INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.JuryVotes target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Log_SoftDelete ON dbo.[Log] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Log] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Manager_SoftDelete ON dbo.[Manager] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Manager] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SoftDelete
ON dbo.PlayAwardCategories
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE AwardCategoryCode = 1001 AND RoleCode = 0)
        THROW 51307, N'System-managed category 1001 cannot be deleted.', 1;

    UPDATE target
    SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories target
    INNER JOIN deleted source ON source.Id = target.Id;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.Plays target
    INNER JOIN deleted source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_PlayStatuses_SoftDelete ON dbo.PlayStatuses INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.PlayStatuses target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Roles_SoftDelete ON dbo.Roles INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Roles target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDelete ON dbo.Users INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.Users target INNER JOIN deleted source ON source.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_UsersLog_SoftDelete ON dbo.UsersLog INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.UsersLog target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

/* EF soft deletes are UPDATE operations, so dependent rows are soft-deleted here. */
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDeleteDependents
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE candidate
    SET candidate.IsPublished = 0,
        candidate.IsActive = 0,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories candidate
    INNER JOIN inserted play ON play.Id = candidate.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND candidate.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted play ON play.Id = assignment.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted play ON play.Id = fee.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted play ON play.Id = blacklist.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDeleteDependents
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE vote SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes vote
    INNER JOIN inserted jury ON jury.Id = vote.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND vote.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted jury ON jury.Id = assignment.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted jury ON jury.Id = fee.UserId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted jury ON jury.Id = blacklist.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO
IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE delete_referential_action <> 0
      AND parent_object_id IN
      (
          SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
      )
)
    THROW 51700, N'At least one dbo foreign key still has a physical delete action.', 1;

SELECT name, delete_referential_action_desc, update_referential_action_desc
FROM sys.foreign_keys
WHERE parent_object_id IN
(
    SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
)
ORDER BY name;
GO