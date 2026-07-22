USE [AfifeAdmin];
GO

SET XACT_ABORT ON;
GO

IF EXISTS (
    SELECT 1
    FROM [dbo].[Users]
    WHERE [RoleCode] = 1
    GROUP BY [Username]
    HAVING COUNT(*) > 1)
    THROW 51001, 'RoleCode 1 icin yinelenen Username kayitlari temizlenmelidir.', 1;
GO

IF EXISTS (
    SELECT 1
    FROM [dbo].[Users]
    WHERE [RoleCode] = 1
    GROUP BY [Email]
    HAVING COUNT(*) > 1)
    THROW 51002, 'RoleCode 1 icin yinelenen Email kayitlari temizlenmelidir.', 1;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE [object_id] = OBJECT_ID(N'dbo.Users')
      AND [name] = N'UX_Users_Admin_Username')
BEGIN
    CREATE UNIQUE INDEX [UX_Users_Admin_Username]
        ON [dbo].[Users] ([Username])
        WHERE [RoleCode] = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE [object_id] = OBJECT_ID(N'dbo.Users')
      AND [name] = N'UX_Users_Admin_Email')
BEGIN
    CREATE UNIQUE INDEX [UX_Users_Admin_Email]
        ON [dbo].[Users] ([Email])
        WHERE [RoleCode] = 1;
END;
GO
