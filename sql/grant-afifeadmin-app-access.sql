USE [master];
GO

SET XACT_ABORT ON;

IF DB_ID(N'AfifeAdmin') IS NULL
    THROW 50001, 'AfifeAdmin veritabani bu SQL Server instance uzerinde bulunamadi.', 1;
GO

IF SUSER_ID(N'KREAN\Krean') IS NULL
    CREATE LOGIN [KREAN\Krean] FROM WINDOWS
        WITH DEFAULT_DATABASE = [AfifeAdmin];
ELSE
    ALTER LOGIN [KREAN\Krean]
        WITH DEFAULT_DATABASE = [AfifeAdmin];
GO

USE [AfifeAdmin];
GO

IF DATABASE_PRINCIPAL_ID(N'KREAN\Krean') IS NULL
    CREATE USER [KREAN\Krean] FOR LOGIN [KREAN\Krean];
GO

GRANT CONNECT TO [KREAN\Krean];
GO

IF IS_ROLEMEMBER(N'db_datareader', N'KREAN\Krean') <> 1
    ALTER ROLE [db_datareader] ADD MEMBER [KREAN\Krean];
GO

IF IS_ROLEMEMBER(N'db_datawriter', N'KREAN\Krean') <> 1
    ALTER ROLE [db_datawriter] ADD MEMBER [KREAN\Krean];
GO

SELECT
    SUSER_SNAME() AS [ScriptExecutedBy],
    DB_NAME() AS [DatabaseName],
    HAS_DBACCESS(N'AfifeAdmin') AS [ExecutorHasDatabaseAccess],
    dp.[name] AS [ApplicationUser],
    dp.[type_desc] AS [UserType]
FROM sys.database_principals AS dp
WHERE dp.[name] = N'KREAN\Krean';
GO
