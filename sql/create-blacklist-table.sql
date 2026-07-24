USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Blacklist', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Blacklist
    (
        Id uniqueidentifier NOT NULL
            CONSTRAINT DF_Blacklist_Id DEFAULT NEWID(),
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        CreatedBy uniqueidentifier NOT NULL,
        CreatedOn datetime2(0) NOT NULL
            CONSTRAINT DF_Blacklist_CreatedOn DEFAULT DATEADD(HOUR, 3, SYSUTCDATETIME()),
        IsPublished bit NOT NULL
            CONSTRAINT DF_Blacklist_IsPublished DEFAULT (1),
        CONSTRAINT PK_Blacklist PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Blacklist_Users_JuryId
            FOREIGN KEY (JuryId) REFERENCES dbo.Users(Id)
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_Blacklist_Plays_PlayId
            FOREIGN KEY (PlayId) REFERENCES dbo.Plays(Id)
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_Blacklist_Users_CreatedBy
            FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id)
            ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Blacklist')
      AND name = N'UX_Blacklist_JuryId_PlayId_Published'
)
BEGIN
    CREATE UNIQUE INDEX UX_Blacklist_JuryId_PlayId_Published
        ON dbo.Blacklist(JuryId, PlayId)
        WHERE IsPublished = 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Blacklist')
      AND name = N'IX_Blacklist_CreatedOn'
)
BEGIN
    CREATE INDEX IX_Blacklist_CreatedOn
        ON dbo.Blacklist(CreatedOn DESC);
END;
GO
