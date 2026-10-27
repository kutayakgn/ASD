param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',
    [string] $Server = $(if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' })
)

$ErrorActionPreference = 'Stop'
if ($Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'Group migration regression requires a disposable SQL Server LocalDB database.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationRoot = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'
$migrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name | ForEach-Object { $_.BaseName })
$targetMigrations = @($migrationIds | Where-Object { $_ -match '^\d{14}_GroupManagement_v_' })
if ($targetMigrations.Count -ne 1) { throw 'Expected exactly one group-management migration.' }
$targetMigration = $targetMigrations[0]
$targetIndex = [Array]::IndexOf($migrationIds, $targetMigration)
if ($targetIndex -lt 1) { throw 'Group-management migration needs a predecessor.' }
$previousMigration = $migrationIds[$targetIndex - 1]
$deletionMigrations = @($migrationIds | Where-Object { $_ -match '^\d{14}_GroupDeletionRules_v_' })
if ($deletionMigrations.Count -ne 1) { throw 'Expected exactly one additive group-deletion migration.' }
$deletionMigration = $deletionMigrations[0]
$databaseName = 'YkbAfifeGroupMigrationTest_' + [Guid]::NewGuid().ToString('N')
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$databaseCreated = $false
$sqlOptions = @'
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
'@

function Assert-GroupMigrationDatabase {
    if ($databaseName -notmatch '^YkbAfifeGroupMigrationTest_[a-f0-9]{32}$' -or
        $Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
        throw 'Refusing an unvalidated disposable LocalDB database.'
    }
}

function Invoke-GroupMigrationSql([string] $Sql) {
    Assert-GroupMigrationDatabase
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q ($sqlOptions + "`n" + $Sql)
    if ($LASTEXITCODE -ne 0) { throw 'Group migration SQL assertion failed.' }
}

function Invoke-GroupMigration([string] $Target, [int] $ExpectedError = 0) {
    $taskOutput = @(dotnet tool run dotnet-ef database update $Target --project $project --startup-project $project `
        --configuration $Configuration --no-build 2>&1)
    $taskExit = $LASTEXITCODE
    if ($ExpectedError -ne 0) {
        if ($taskExit -eq 0 -or ($taskOutput -join "`n") -notmatch "$ExpectedError") {
            $taskOutput | ForEach-Object { Write-Host $_ }
            throw "Expected safe migration failure $ExpectedError."
        }
        Write-Host "PASS: unsupported dependent schema safely rejects migration with SQL $ExpectedError."
    } else {
        $taskOutput | ForEach-Object { Write-Host $_ }
        if ($taskExit -ne 0) { throw "Group migration to $Target failed." }
    }
}

Push-Location $repositoryRoot
try {
    Assert-GroupMigrationDatabase
    sqlcmd -I -S $Server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53620, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Group migration disposable database creation failed.' }
    $databaseCreated = $true
    $env:ConnectionStrings__AfifeConnectionString = "Server=$Server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
    Invoke-GroupMigration $previousMigration
    Invoke-GroupMigrationSql @'
CREATE TABLE dbo.GroupMigrationExtra
(
    Id uniqueidentifier NOT NULL PRIMARY KEY,
    GroupCode int NULL,
    GroupId uniqueidentifier NOT NULL,
    Payload nvarchar(100) NOT NULL,
    CONSTRAINT FK_GroupMigrationExtra_Code FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code),
    CONSTRAINT FK_GroupMigrationExtra_Id FOREIGN KEY (GroupId) REFERENCES dbo.[Group](Id)
);
CREATE TABLE dbo.GroupMigrationExistingCascade
(
    Id uniqueidentifier NOT NULL PRIMARY KEY,
    GroupCode int NOT NULL,
    Payload nvarchar(100) NOT NULL,
    CONSTRAINT FK_GroupMigrationExistingCascade_Code FOREIGN KEY (GroupCode) REFERENCES dbo.[Group](Code) ON UPDATE CASCADE
);
DECLARE @Published uniqueidentifier = NEWID(), @Hidden uniqueidentifier = NEWID();
INSERT dbo.[Group] (Id, Code, GroupName, CreatedAt, IsPublished)
VALUES (@Published, 987601, N'Migration published group', '2099-01-01', 1),
       (@Hidden, 987602, N'Migration hidden group', '2099-01-01', 0);
INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, CreatedAt,
    IsPublished, RoleCode, GroupCode, IsActive, IsJuryPresident)
VALUES (NEWID(), N'Existing', N'Published', N'group.migration.published', N'opaque hash preserved exactly ',
    N'group.migration.published@example.invalid', '2099-01-01', 1, 2, 987601, 1, 0),
       (NEWID(), N'Existing', N'Hidden', N'group.migration.hidden', N'opaque hidden hash preserved exactly ',
    N'group.migration.hidden@example.invalid', '2099-01-01', 0, 2, 987602, 0, 0);
INSERT dbo.GroupMigrationExtra (Id, GroupCode, GroupId, Payload)
VALUES (NEWID(), 987601, @Published, N'extra published payload '),
       (NEWID(), 987602, @Hidden, N'extra hidden payload ');
INSERT dbo.GroupMigrationExistingCascade (Id, GroupCode, Payload)
VALUES (NEWID(), 987601, N'pre-existing cascade payload '),
       (NEWID(), 987602, N'pre-existing hidden cascade payload ');
DECLARE @Snapshot varbinary(32) = HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code IN (987601, 987602) ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'group.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExtra ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExistingCascade ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)));
EXEC sys.sp_addextendedproperty @name = N'AfifeTest:GroupMigrationSnapshot', @value = @Snapshot;
'@
    # An unknown dependent table must never be skipped when update cascading
    # cannot be installed. Earlier FK/index DDL must roll back with the failure.
    Invoke-GroupMigrationSql "EXEC(N'CREATE TRIGGER dbo.TR_GroupMigrationExtra_Update ON dbo.GroupMigrationExtra INSTEAD OF UPDATE AS BEGIN SET NOCOUNT ON; END;');"
    Invoke-GroupMigration $targetMigration -ExpectedError 52824
    Invoke-GroupMigrationSql @"
IF EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory WHERE MigrationId = N'$targetMigration')
    THROW 53621, N'Failed migration history was committed.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name IN (N'FK_Users_Group', N'FK_GroupMigrationExtra_Code') AND update_referential_action <> 0)
    THROW 53622, N'Failed migration committed FK changes.', 1;
DROP TRIGGER dbo.TR_GroupMigrationExtra_Update;
"@
    Invoke-GroupMigration $targetMigration
    Invoke-GroupMigrationSql @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class = 0 AND name = N'AfifeTest:GroupMigrationSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code IN (987601, 987602) ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'group.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExtra ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExistingCascade ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53623, N'Migration changed existing group, user or external dependent data.', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE name IN (N'FK_Users_Group', N'FK_GroupMigrationExtra_Code', N'FK_GroupMigrationExistingCascade_Code')
    AND update_referential_action = 1 AND delete_referential_action = 0 AND is_disabled = 0 AND is_not_trusted = 0) <> 3
    THROW 53624, N'Not every Code foreign key became an enabled trusted update cascade.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_GroupMigrationExtra_Id' AND update_referential_action = 0)
    THROW 53625, N'Unrelated Group.Id reference was changed.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes AS lookupIndex
    JOIN sys.index_columns AS indexColumn ON indexColumn.object_id = lookupIndex.object_id AND indexColumn.index_id = lookupIndex.index_id
    JOIN sys.columns AS columnRecord ON columnRecord.object_id = indexColumn.object_id AND columnRecord.column_id = indexColumn.column_id
    WHERE lookupIndex.object_id = OBJECT_ID(N'dbo.GroupMigrationExtra') AND lookupIndex.is_disabled = 0
      AND indexColumn.key_ordinal = 1 AND columnRecord.name = N'GroupCode')
    THROW 53626, N'Dependent lookup index was not installed.', 1;
PRINT N'PASS: deployment preserves every existing value and configures indexed Code cascades, including external tables.';
UPDATE dbo.[Group] SET Code = Code + 100 WHERE Code IN (987601, 987602);
IF (SELECT COUNT(*) FROM dbo.Users WHERE Username LIKE N'group.migration.%' AND GroupCode IN (987701, 987702)) <> 2
   OR (SELECT COUNT(*) FROM dbo.GroupMigrationExtra WHERE GroupCode IN (987701, 987702)) <> 2
   OR (SELECT COUNT(*) FROM dbo.GroupMigrationExistingCascade WHERE GroupCode IN (987701, 987702)) <> 2
    THROW 53627, N'Published or hidden group Code rename lost a dependent relationship.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'group.migration.hidden'
    AND IsPublished = 0 AND IsActive = 0 AND PasswordHash = N'opaque hidden hash preserved exactly ')
    THROW 53628, N'Hidden membership rename changed account state/hash.', 1;
DECLARE @RenamedSnapshot varbinary(32) = HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code IN (987701, 987702) ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'group.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExtra ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExistingCascade ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)));
EXEC sys.sp_updateextendedproperty @name = N'AfifeTest:GroupMigrationSnapshot', @value = @RenamedSnapshot;
PRINT N'PASS: multirow published/hidden group Code changes atomically update users and every external Code reference.';
'@
    Invoke-GroupMigration $previousMigration
    Invoke-GroupMigrationSql @'
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE name IN (N'FK_Users_Group', N'FK_GroupMigrationExtra_Code')
    AND update_referential_action = 0 AND is_disabled = 0 AND is_not_trusted = 0) <> 2
    THROW 53629, N'Down did not restore original FK update rules.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_GroupMigrationExistingCascade_Code' AND update_referential_action = 1)
    THROW 53630, N'Down replaced a pre-existing CASCADE rule.', 1;
IF OBJECT_ID(N'dbo.TR_Group_ProtectAssignments', N'TR') IS NOT NULL
    OR OBJECT_ID(N'dbo.TR_Users_ValidateGroupAssignment', N'TR') IS NOT NULL
    THROW 53631, N'Down left new assignment triggers installed.', 1;
PRINT N'PASS: Down restores prior FK behavior while preserving pre-existing cascade rules and all row data.';
'@
    Invoke-GroupMigration $targetMigration
    Invoke-GroupMigrationSql @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class = 0 AND name = N'AfifeTest:GroupMigrationSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code IN (987701, 987702) ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'group.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExtra ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExistingCascade ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53632, N'Up/Down/Up changed existing group, user or dependent row values.', 1;
PRINT N'PASS: Up/Down/Up preserves every existing group/user/external row value, including password hashes.';
'@
    # The published GroupManagement package remains immutable. Already-upgraded
    # deployments receive the revised deletion rule through an additive version.
    Invoke-GroupMigration $deletionMigration
    Invoke-GroupMigrationSql @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class = 0 AND name = N'AfifeTest:GroupMigrationSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code IN (987701, 987702) ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'group.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExtra ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.GroupMigrationExistingCascade ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53633, N'Additive group-deletion migration changed existing row values.', 1;
INSERT dbo.[Group] (Id, Code, GroupName, CreatedAt, IsPublished)
VALUES (NEWID(), 988101, N'Deleted jury only', '2099-01-01', 1),
       (NEWID(), 988102, N'Admin only', '2099-01-01', 1),
       (NEWID(), 988103, N'Inactive published jury', '2099-01-01', 1),
       (NEWID(), 988104, N'Unchanged legacy admin', '2099-01-01', 1),
       (NEWID(), 988105, N'Additive rollback admin', '2099-01-01', 1);
INSERT dbo.Users (Id, FirstName, LastName, Username, PasswordHash, Email, CreatedAt,
    IsPublished, RoleCode, GroupCode, IsActive, IsJuryPresident)
SELECT NEWID(), N'Existing', N'Preserved', fixture.Username, N'opaque preserved deletion hash ',
    fixture.Username + N'@example.invalid', '2099-01-01', fixture.Published,
    fixture.RoleCode, fixture.GroupCode, fixture.Active, 0
FROM (VALUES
    (N'rule.migration.deleted', 0, 2, 988101, 0),
    (N'rule.migration.admin', 1, 1, 988102, 1),
    (N'rule.migration.inactive', 1, 2, 988103, 0),
    (N'rule.migration.legacyadmin', 1, 1, 988104, 1),
    (N'rule.migration.rollbackadmin', 1, 1, 988105, 1)
) fixture(Username, Published, RoleCode, GroupCode, Active);
DECLARE @BeforeRemoval varbinary(32) = HASHBYTES('SHA2_256',
    (SELECT * FROM dbo.Users WHERE Username LIKE N'rule.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES));
UPDATE dbo.[Group] SET IsPublished = 0 WHERE Code IN (988101, 988104);
DELETE dbo.[Group] WHERE Code = 988102;
IF (SELECT COUNT(*) FROM dbo.[Group] WHERE Code IN (988101, 988102, 988104) AND IsPublished = 0) <> 3
    THROW 53634, N'Deleted-jury/admin groups did not remain as soft-deleted rows.', 1;
IF @BeforeRemoval <> HASHBYTES('SHA2_256',
    (SELECT * FROM dbo.Users WHERE Username LIKE N'rule.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES))
    THROW 53635, N'Group removal changed existing user data or GroupCode membership.', 1;
DECLARE @Rejected bit = 0;
BEGIN TRY
    UPDATE dbo.[Group] SET IsPublished = 0 WHERE Code = 988103;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52820 THROW;
    SET @Rejected = 1;
END CATCH;
IF @Rejected = 0 OR NOT EXISTS (SELECT 1 FROM dbo.[Group] WHERE Code = 988103 AND IsPublished = 1)
    THROW 53636, N'Inactive but published jury did not block group removal.', 1;
SET @Rejected = 0;
BEGIN TRY
    UPDATE dbo.Users SET IsPublished = 1 WHERE Username = N'rule.migration.deleted';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52821 THROW;
    SET @Rejected = 1;
END CATCH;
IF @Rejected = 0 OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'rule.migration.deleted' AND IsPublished = 0)
    THROW 53637, N'Restoring a deleted jury bypassed its deleted group validation.', 1;
SET @Rejected = 0;
BEGIN TRY
    UPDATE dbo.Users SET RoleCode = 2 WHERE Username = N'rule.migration.admin';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52821 THROW;
    SET @Rejected = 1;
END CATCH;
IF @Rejected = 0 OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'rule.migration.admin' AND RoleCode = 1)
    THROW 53638, N'Changing an admin to a jury bypassed its deleted group validation.', 1;
UPDATE dbo.Users SET LastName = N'Edited historical profile'
WHERE Username IN (N'rule.migration.admin', N'rule.migration.deleted', N'rule.migration.legacyadmin');
IF (SELECT COUNT(*) FROM dbo.Users WHERE Username IN (N'rule.migration.admin', N'rule.migration.deleted', N'rule.migration.legacyadmin')
    AND LastName = N'Edited historical profile' AND GroupCode IN (988101, 988102, 988104)) <> 3
    THROW 53639, N'Historical deleted/admin membership prevented unrelated profile updates.', 1;
DECLARE @BeforeRollback varbinary(32) = HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code BETWEEN 988101 AND 988105 ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'rule.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES)));
EXEC sys.sp_addextendedproperty @name = N'AfifeTest:GroupDeletionRulesSnapshot', @value = @BeforeRollback;
PRINT N'PASS: deleted juries/admins allow soft removal without any membership/account changes; inactive published juries block it.';
PRINT N'PASS: restoring/promoting a jury validates its group while historical profile edits remain available.';
'@
    Invoke-GroupMigration $targetMigration
    Invoke-GroupMigrationSql @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class = 0 AND name = N'AfifeTest:GroupDeletionRulesSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code BETWEEN 988101 AND 988105 ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'rule.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53640, N'Additive rule rollback changed group/user row values.', 1;
DECLARE @Rejected bit = 0;
BEGIN TRY
    DELETE dbo.[Group] WHERE Code = 988105;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 52820 THROW;
    SET @Rejected = 1;
END CATCH;
IF @Rejected = 0 OR NOT EXISTS (SELECT 1 FROM dbo.[Group] WHERE Code = 988105 AND IsPublished = 1)
    THROW 53641, N'Additive Down did not restore the preceding immutable deletion rule.', 1;
PRINT N'PASS: additive Down restores the old guard without changing any group/user values.';
'@
    Invoke-GroupMigration $deletionMigration
    Invoke-GroupMigrationSql @'
DECLARE @Snapshot varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties WHERE class = 0 AND name = N'AfifeTest:GroupDeletionRulesSnapshot');
IF @Snapshot <> HASHBYTES('SHA2_256', CONCAT(
    (SELECT * FROM dbo.[Group] WHERE Code BETWEEN 988101 AND 988105 ORDER BY Code FOR JSON PATH, INCLUDE_NULL_VALUES),
    (SELECT * FROM dbo.Users WHERE Username LIKE N'rule.migration.%' ORDER BY Username FOR JSON PATH, INCLUDE_NULL_VALUES)))
    THROW 53642, N'Additive Up/Down/Up changed group/user row values.', 1;
DELETE dbo.[Group] WHERE Code = 988105;
IF NOT EXISTS (SELECT 1 FROM dbo.[Group] WHERE Code = 988105 AND IsPublished = 0)
    OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'rule.migration.rollbackadmin'
        AND GroupCode = 988105 AND PasswordHash = N'opaque preserved deletion hash ')
    THROW 53643, N'Additive Up did not restore permissive admin-only soft removal with membership intact.', 1;
PRINT N'PASS: additive Up/Down/Up preserves account/hash/membership values and restores the revised deletion rule.';
'@
    Write-Host "Group migration Up/Down/Up regression passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    if ($databaseCreated) {
        Assert-GroupMigrationDatabase
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable group migration database cleanup failed: $databaseName" }
    }
    Pop-Location
}
