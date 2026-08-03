SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.AdditionalVotings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AdditionalVotings
    (
        Id uniqueidentifier NOT NULL CONSTRAINT PK_AdditionalVotings PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        StartDate date NOT NULL,
        EndDate date NOT NULL,
        AppliesToAllJuries bit NOT NULL CONSTRAINT DF_AdditionalVotings_AllJuries DEFAULT (0),
        AppliesToAllPlays bit NOT NULL CONSTRAINT DF_AdditionalVotings_AllPlays DEFAULT (0),
        CreatedAt datetime2(7) NOT NULL CONSTRAINT DF_AdditionalVotings_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy uniqueidentifier NULL,
        UpdatedAt datetime2(7) NULL,
        UpdatedBy uniqueidentifier NULL,
        IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotings_IsActive DEFAULT (1),
        IsPublished bit NOT NULL CONSTRAINT DF_AdditionalVotings_IsPublished DEFAULT (1),
        CONSTRAINT CK_AdditionalVotings_DateRange CHECK (StartDate < EndDate),
        CONSTRAINT FK_AdditionalVotings_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotings_Users_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END;

IF OBJECT_ID(N'dbo.AdditionalVotingJuries', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AdditionalVotingJuries
    (
        Id uniqueidentifier NOT NULL CONSTRAINT PK_AdditionalVotingJuries PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        AdditionalVotingId uniqueidentifier NOT NULL,
        JuryId uniqueidentifier NOT NULL,
        CreatedAt datetime2(7) NOT NULL CONSTRAINT DF_AdditionalVotingJuries_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy uniqueidentifier NULL,
        UpdatedAt datetime2(7) NULL,
        UpdatedBy uniqueidentifier NULL,
        IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingJuries_IsActive DEFAULT (1),
        IsPublished bit NOT NULL CONSTRAINT DF_AdditionalVotingJuries_IsPublished DEFAULT (1),
        CONSTRAINT FK_AdditionalVotingJuries_AdditionalVotings FOREIGN KEY (AdditionalVotingId) REFERENCES dbo.AdditionalVotings(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingJuries_Users_Jury FOREIGN KEY (JuryId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingJuries_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingJuries_Users_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingJuries') AND name = N'UX_AdditionalVotingJuries_Published')
    CREATE UNIQUE INDEX UX_AdditionalVotingJuries_Published ON dbo.AdditionalVotingJuries(AdditionalVotingId, JuryId) WHERE IsPublished = 1;

IF OBJECT_ID(N'dbo.AdditionalVotingPlays', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AdditionalVotingPlays
    (
        Id uniqueidentifier NOT NULL CONSTRAINT PK_AdditionalVotingPlays PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        AdditionalVotingId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        CreatedAt datetime2(7) NOT NULL CONSTRAINT DF_AdditionalVotingPlays_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy uniqueidentifier NULL,
        UpdatedAt datetime2(7) NULL,
        UpdatedBy uniqueidentifier NULL,
        IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingPlays_IsActive DEFAULT (1),
        IsPublished bit NOT NULL CONSTRAINT DF_AdditionalVotingPlays_IsPublished DEFAULT (1),
        CONSTRAINT FK_AdditionalVotingPlays_AdditionalVotings FOREIGN KEY (AdditionalVotingId) REFERENCES dbo.AdditionalVotings(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingPlays_Plays FOREIGN KEY (PlayId) REFERENCES dbo.Plays(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingPlays_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingPlays_Users_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingPlays') AND name = N'UX_AdditionalVotingPlays_Published')
    CREATE UNIQUE INDEX UX_AdditionalVotingPlays_Published ON dbo.AdditionalVotingPlays(AdditionalVotingId, PlayId) WHERE IsPublished = 1;

IF OBJECT_ID(N'dbo.AdditionalVotingUsages', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AdditionalVotingUsages
    (
        Id uniqueidentifier NOT NULL CONSTRAINT PK_AdditionalVotingUsages PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        AdditionalVotingId uniqueidentifier NOT NULL,
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        UsageType tinyint NOT NULL,
        UsedAt datetime2(7) NOT NULL CONSTRAINT DF_AdditionalVotingUsages_UsedAt DEFAULT SYSDATETIME(),
        CreatedAt datetime2(7) NOT NULL CONSTRAINT DF_AdditionalVotingUsages_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy uniqueidentifier NULL,
        UpdatedAt datetime2(7) NULL,
        UpdatedBy uniqueidentifier NULL,
        IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingUsages_IsActive DEFAULT (1),
        IsPublished bit NOT NULL CONSTRAINT DF_AdditionalVotingUsages_IsPublished DEFAULT (1),
        CONSTRAINT CK_AdditionalVotingUsages_UsageType CHECK (UsageType IN (0, 1)),
        CONSTRAINT FK_AdditionalVotingUsages_AdditionalVotings FOREIGN KEY (AdditionalVotingId) REFERENCES dbo.AdditionalVotings(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingUsages_Users_Jury FOREIGN KEY (JuryId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingUsages_Plays FOREIGN KEY (PlayId) REFERENCES dbo.Plays(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingUsages_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_AdditionalVotingUsages_Users_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(Id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END;

IF COL_LENGTH(N'dbo.AdditionalVotings', N'IsActive') IS NULL
    ALTER TABLE dbo.AdditionalVotings ADD IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotings_IsActive DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.AdditionalVotingJuries', N'IsActive') IS NULL
    ALTER TABLE dbo.AdditionalVotingJuries ADD IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingJuries_IsActive DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.AdditionalVotingPlays', N'IsActive') IS NULL
    ALTER TABLE dbo.AdditionalVotingPlays ADD IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingPlays_IsActive DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.AdditionalVotingUsages', N'IsActive') IS NULL
    ALTER TABLE dbo.AdditionalVotingUsages ADD IsActive bit NOT NULL CONSTRAINT DF_AdditionalVotingUsages_IsActive DEFAULT (1) WITH VALUES;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages') AND name = N'IX_AdditionalVotingUsages_Lookup')
    CREATE INDEX IX_AdditionalVotingUsages_Lookup ON dbo.AdditionalVotingUsages(AdditionalVotingId, UsageType, JuryId) WHERE IsPublished = 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdditionalVotingUsages') AND name = N'UX_AdditionalVotingUsages_OneTime')
    CREATE UNIQUE INDEX UX_AdditionalVotingUsages_OneTime ON dbo.AdditionalVotingUsages(AdditionalVotingId, JuryId, PlayId) WHERE IsPublished = 1;

COMMIT TRANSACTION;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotings_SoftDelete
ON dbo.AdditionalVotings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2(7) = SYSDATETIME();
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotings target INNER JOIN deleted d ON d.Id = target.Id;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingJuries_SoftDelete ON dbo.AdditionalVotingJuries INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingPlays_SoftDelete ON dbo.AdditionalVotingPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.Id; END;
GO
CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingUsages_SoftDelete ON dbo.AdditionalVotingUsages INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

-- IMPORTANT: Run sql/create-admin-audit-logging.sql after this file so all four
-- new business tables receive the standard AdminLogs audit triggers.
