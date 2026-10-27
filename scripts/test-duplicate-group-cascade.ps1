param([string] $Server = '(localdb)\AfifeMigrationCheck')
$ErrorActionPreference = 'Stop'
if ($Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'Duplicate Group FK regression permits SQL Server LocalDB only.'
}
$databaseName = 'YkbAfifeCascadeReproTest_' + [Guid]::NewGuid().ToString('N')
if ($databaseName -notmatch '^YkbAfifeCascadeReproTest_[a-f0-9]{32}$') {
    throw 'Disposable duplicate FK database validation failed.'
}
$databaseCreated = $false
try {
    sqlcmd -I -S $Server -d master -b -l 30 -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable duplicate FK database creation failed.' }
    $databaseCreated = $true
    $sql = @'
SET NOCOUNT ON;
SET XACT_ABORT ON;
CREATE TABLE dbo.[Group]
(
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Group PRIMARY KEY,
    Code int NOT NULL CONSTRAINT UQ_Group_Code UNIQUE,
    GroupName nvarchar(100) NOT NULL
);
CREATE TABLE dbo.Users
(
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    GroupCode int NULL,
    PasswordHash nvarchar(500) NOT NULL,
    CONSTRAINT FK_Users_Group FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code),
    CONSTRAINT FK_Users_Groups FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code)
);
INSERT dbo.[Group] (Id, Code, GroupName)
VALUES ('328B0BE2-6DD4-47B7-AF13-C9AFBE5B0E87', 91, N'Duplicate FK group');
INSERT dbo.Users (Id, GroupCode, PasswordHash)
VALUES ('CA6CB6EF-D785-4DF5-9492-2D13E2742458', 91, N'opaque hash preserved exactly ');

ALTER TABLE dbo.Users DROP CONSTRAINT FK_Users_Group;
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Group
    FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code) ON UPDATE CASCADE;
'@
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $sql
    if ($LASTEXITCODE -ne 0) { throw 'Duplicate FK fixture creation failed.' }
    # SQL CATCH sees the final 1750 wrapper. Capture the full SQL client error
    # chain instead, proving that its preceding diagnostic is exactly 1785.
    $failingSql = @'
SET XACT_ABORT ON;
BEGIN TRANSACTION;
ALTER TABLE dbo.Users DROP CONSTRAINT FK_Users_Groups;
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Groups
    FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code) ON UPDATE CASCADE;
COMMIT TRANSACTION;
'@
    $failureOutput = @(sqlcmd -I -S $Server -d $databaseName -b -l 30 -t 180 -Q $failingSql 2>&1)
    if ($LASTEXITCODE -eq 0 -or ($failureOutput -join "`n") -notmatch 'Msg 1785') {
        $failureOutput | ForEach-Object { Write-Host $_ }
        throw 'Expected duplicate cascading FK path to reproduce SQL 1785.'
    }
    Write-Host 'PASS: canonical FK_Users_Group plus legacy FK_Users_Groups reproduces SQL 1785 when both are changed to CASCADE.'
    $sql = @'
SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.Users')) <> 2
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Users_Group' AND update_referential_action = 1)
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Users_Groups' AND update_referential_action = 0)
    THROW 53811, N'The failed FK change was not rolled back to one CASCADE plus one NO ACTION.', 1;

UPDATE dbo.[Group] SET Code = 92 WHERE Id = '328B0BE2-6DD4-47B7-AF13-C9AFBE5B0E87';
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = 'CA6CB6EF-D785-4DF5-9492-2D13E2742458'
    AND GroupCode = 92 AND CONVERT(varbinary(max), PasswordHash) = CONVERT(varbinary(max), N'opaque hash preserved exactly '))
    THROW 53812, N'Keeping the equivalent NO ACTION FK prevented the valid cascade or changed account data.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.[Group] WHERE Id = '328B0BE2-6DD4-47B7-AF13-C9AFBE5B0E87'
    AND Code = 92 AND GroupName = N'Duplicate FK group')
    THROW 53813, N'Code update changed the group identity/name.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.Users')
    AND (is_disabled = 1 OR is_not_trusted = 1 OR delete_referential_action <> 0))
    THROW 53814, N'Equivalent constraints must remain enabled/trusted with NO ACTION deletion.', 1;
PRINT N'PASS: one CASCADE plus equivalent NO ACTION FK updates GroupCode atomically while preserving Group/User Id, name, hash and both trusted constraints.';
'@
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $sql
    if ($LASTEXITCODE -ne 0) { throw 'Duplicate Group FK SQL regression failed.' }

    $canonicalPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/YKBAfife/Migrations/DatabaseObjects/00-Prerequisites/GroupCodeCascade.sql'
    $canonicalSql = Get-Content -Raw -LiteralPath $canonicalPath
    # Start with both constraints NO ACTION, as in company schema adoption,
    # and retain the historical rollback marker when the winner is rebuilt.
    $setupSql = @'
ALTER TABLE dbo.Users DROP CONSTRAINT FK_Users_Group;
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Group
    FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code);
EXEC sys.sp_addextendedproperty @name=N'Afife:GroupCodeOriginalUpdateAction', @value=0,
    @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Users',
    @level2type=N'CONSTRAINT', @level2name=N'FK_Users_Group';
CREATE TABLE dbo.GroupExternalReference
(
    Id int NOT NULL PRIMARY KEY,
    GroupCode int NOT NULL,
    CONSTRAINT FK_GroupExternalReference_Group FOREIGN KEY(GroupCode) REFERENCES dbo.[Group](Code)
);
INSERT dbo.GroupExternalReference (Id, GroupCode) VALUES (1, 92);
DECLARE @Snapshot varbinary(32) = HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupExternalReference ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)));
EXEC sys.sp_addextendedproperty @name=N'AfifeTest:DuplicateFKSnapshot', @value=@Snapshot;
'@
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $setupSql
    if ($LASTEXITCODE -ne 0) { throw 'Canonical duplicate FK fixture setup failed.' }
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $canonicalSql
    if ($LASTEXITCODE -ne 0) { throw 'Corrected canonical duplicate FK installation failed.' }
    $assertSql = @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class=0 AND name=N'AfifeTest:DuplicateFKSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupExternalReference ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53815, N'Constraint installation changed existing Group, User or external reference rows.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_Users_Group' AND update_referential_action=1)
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_Users_Groups' AND update_referential_action=0)
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_GroupExternalReference_Group' AND update_referential_action=1)
    THROW 53816, N'Canonical winner or distinct external mapping was not configured.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties AS property
    INNER JOIN sys.foreign_keys AS fk ON fk.object_id=property.major_id
    WHERE property.class=1 AND property.name=N'Afife:GroupCodeOriginalUpdateAction'
      AND fk.name=N'FK_Users_Group' AND TRY_CONVERT(int,property.value)=0)
    THROW 53817, N'Rebuilding the FK lost the saved original update rule.', 1;
UPDATE dbo.[Group] SET Code=93 WHERE Id='328B0BE2-6DD4-47B7-AF13-C9AFBE5B0E87';
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE GroupCode=93
    AND CONVERT(varbinary(max),PasswordHash)=CONVERT(varbinary(max),N'opaque hash preserved exactly '))
   OR NOT EXISTS (SELECT 1 FROM dbo.GroupExternalReference WHERE Id=1 AND GroupCode=93)
    THROW 53818, N'Corrected duplicate constraints failed to update every distinct reference.', 1;
PRINT N'PASS: corrected installer preserves all data and rollback marker, configures exactly one equivalent cascade, and updates external references.';

/* An already valid legacy cascading winner must stay in place instead of
   being swapped to the canonical name and disturbing its rollback history. */
ALTER TABLE dbo.Users DROP CONSTRAINT FK_Users_Group;
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Group
    FOREIGN KEY(GroupCode) REFERENCES dbo.[Group](Code);
ALTER TABLE dbo.Users DROP CONSTRAINT FK_Users_Groups;
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Groups
    FOREIGN KEY(GroupCode) REFERENCES dbo.[Group](Code) ON UPDATE CASCADE;
EXEC sys.sp_addextendedproperty @name=N'Afife:GroupCodeOriginalUpdateAction', @value=0,
    @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Users',
    @level2type=N'CONSTRAINT', @level2name=N'FK_Users_Groups';
'@
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $assertSql
    if ($LASTEXITCODE -ne 0) { throw 'Corrected canonical duplicate FK assertions failed.' }
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $canonicalSql
    if ($LASTEXITCODE -ne 0) { throw 'Legacy cascading winner installation failed.' }
    # A second execution is deliberately idempotent.
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $canonicalSql
    if ($LASTEXITCODE -ne 0) { throw 'Duplicate FK installer was not idempotent.' }
    $legacyAssert = @'
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_Users_Groups' AND update_referential_action=1)
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_Users_Group' AND update_referential_action=0)
    THROW 53819, N'Existing legacy cascade winner was unnecessarily swapped.', 1;
UPDATE dbo.[Group] SET Code=94 WHERE Id='328B0BE2-6DD4-47B7-AF13-C9AFBE5B0E87';
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE GroupCode=94
    AND CONVERT(varbinary(max),PasswordHash)=CONVERT(varbinary(max),N'opaque hash preserved exactly '))
   OR NOT EXISTS (SELECT 1 FROM dbo.GroupExternalReference WHERE Id=1 AND GroupCode=94)
    THROW 53820, N'Preserving the legacy cascade winner lost a dependent reference.', 1;
PRINT N'PASS: existing legacy cascade winner is retained, repeated installation is idempotent and all reference updates remain atomic.';
'@
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $legacyAssert
    if ($LASTEXITCODE -ne 0) { throw 'Legacy cascade winner assertions failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeCascadeReproTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable duplicate Group FK database cleanup failed.' }
    }
}
