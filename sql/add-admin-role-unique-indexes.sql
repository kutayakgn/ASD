USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.Users
    WHERE IsPublished = 1
    GROUP BY RoleCode, Username
    HAVING COUNT_BIG(*) > 1
)
    THROW 51001, 'Ayni RoleCode icinde yinelenen aktif Username kayitlari temizlenmelidir.', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.Users
    WHERE IsPublished = 1
    GROUP BY RoleCode, Email
    HAVING COUNT_BIG(*) > 1
)
    THROW 51002, 'Ayni RoleCode icinde yinelenen aktif Email kayitlari temizlenmelidir.', 1;
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Admin_Username')
    DROP INDEX UX_Users_Admin_Username ON dbo.Users;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Admin_Email')
    DROP INDEX UX_Users_Admin_Email ON dbo.Users;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_RoleCode_Username_Published')
    CREATE UNIQUE INDEX UX_Users_RoleCode_Username_Published
        ON dbo.Users (RoleCode, Username)
        WHERE IsPublished = 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_RoleCode_Email_Published')
    CREATE UNIQUE INDEX UX_Users_RoleCode_Email_Published
        ON dbo.Users (RoleCode, Email)
        WHERE IsPublished = 1;
GO