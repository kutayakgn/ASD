param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',
    [string] $Server = $(if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' })
)

$ErrorActionPreference = 'Stop'
if ($Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
    ($env:AFIFE_TEST_SQL_SERVER -and $env:AFIFE_TEST_SQL_SERVER -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$')) {
    throw 'Previous-production regression requires a local SQL Server LocalDB instance.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationRoot = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'
$migrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name | ForEach-Object { $_.BaseName })
$targetMigrations = @($migrationIds | Where-Object { $_ -match '^\d{14}_FormPreviousProductionVersion_v_' })
if ($targetMigrations.Count -ne 1) { throw 'Expected exactly one previous-production migration.' }
$targetMigration = $targetMigrations[0]
$targetIndex = [Array]::IndexOf($migrationIds, $targetMigration)
if ($targetIndex -lt 1) { throw 'Previous-production migration requires a predecessor.' }
$previousMigration = $migrationIds[$targetIndex - 1]
$databaseName = 'YkbAfifePreviousProductionTest_' + [Guid]::NewGuid().ToString('N')
$oldFormId = [Guid]::NewGuid().ToString()
$trueFormId = [Guid]::NewGuid().ToString()
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$databaseCreated = $false

function Assert-PreviousProductionDatabase {
    if ($databaseName -notmatch '^YkbAfifePreviousProductionTest_[a-f0-9]{32}$' -or
        $Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
        throw 'Refusing an unvalidated disposable LocalDB database.'
    }
}

function Invoke-PreviousProductionMigration([string] $Target, [switch] $ExpectNullableDirectorBlock) {
    $taskMigrationOutput = @(dotnet tool run dotnet-ef database update $Target --project $project --startup-project $project `
        --configuration $Configuration --no-build 2>&1)
    $taskMigrationExit = $LASTEXITCODE
    $taskMigrationOutput | ForEach-Object { Write-Host $_ }
    if ($ExpectNullableDirectorBlock) {
        if ($taskMigrationExit -eq 0 -or ($taskMigrationOutput -join "`n") -notmatch '52761') {
            throw 'Down must fail safely with SQL 52761 when a real NULL Director cannot fit the old required schema.'
        }
    } elseif ($taskMigrationExit -ne 0) { throw "Previous-production migration to $Target failed." }
}

function Invoke-PreviousProductionSql([string] $Sql) {
    Assert-PreviousProductionDatabase
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -Q $Sql
    if ($LASTEXITCODE -ne 0) { throw 'Previous-production SQL verification failed.' }
}

Push-Location $repositoryRoot
try {
    Assert-PreviousProductionDatabase
    sqlcmd -I -S $Server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53580, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Previous-production disposable database creation failed.' }
    $databaseCreated = $true
    $env:ConnectionStrings__AfifeConnectionString = "Server=$Server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"

    Invoke-PreviousProductionMigration $previousMigration
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
INSERT dbo.Form (Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
    TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email,
    Director, IsPublished, IsActive)
VALUES ('$oldFormId', N'PP9001', '2099-04-01T12:00:00', '2099-04-01T12:01:00',
    N'Previous production existing $oldFormId', N'Previous production theatre',
    '2099-04-01', N'[]', N'Existing applicant', N'Contact', N'5550000000',
    N'previous@example.invalid', N'Existing director', 1, 1);
DECLARE @Before nvarchar(4000) =
    (SELECT * FROM dbo.Form WHERE Id = '$oldFormId' FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER);
EXEC sys.sp_addextendedproperty @name = N'AfifeTest:PreviousProductionSnapshot', @value = @Before;
"@
    Invoke-PreviousProductionMigration $targetMigration
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = '$oldFormId' AND previousProductionVersion = 0)
    THROW 53581, N'Existing Form did not receive the false default.', 1;
DECLARE @Before nvarchar(max) =
    (SELECT CONVERT(nvarchar(max), value) FROM sys.extended_properties
     WHERE class = 0 AND name = N'AfifeTest:PreviousProductionSnapshot');
DECLARE @After nvarchar(max) = JSON_MODIFY(
    (SELECT * FROM dbo.Form WHERE Id = '$oldFormId' FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER),
    N'$.previousProductionVersion', NULL);
IF @Before IS NULL OR CONVERT(varbinary(max), @Before) <> CONVERT(varbinary(max), @After)
    THROW 53582, N'Adding the flag changed an existing Form field.', 1;
PRINT N'PASS: existing Form retained every field and received false.';
"@

    Assert-PreviousProductionDatabase
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 `
        -i (Join-Path $PSScriptRoot 'test-form-previous-production.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Previous-production SQL regression failed.' }

    # These committed fixture rows exercise real column archival and restoration.
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
INSERT dbo.Form (Id, ApplicationNumber, CreatedDate, RepertoireName, TheatreName,
    PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email, Director,
    previousProductionVersion, IsPublished, IsActive)
VALUES ('$trueFormId', N'PP9002', '2099-04-01T12:00:00',
    N'Previous production retained $trueFormId', N'Previous production theatre',
    '2099-04-01', N'[]', N'Retained applicant', N'Contact', N'5550000000',
    N'previous@example.invalid', N'Retained director', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = '$trueFormId' AND previousProductionVersion = 1 AND Director IS NULL)
    THROW 53588, N'True migration fixture did not normalize its director to SQL NULL.', 1;
DECLARE @BeforeDown varbinary(32) = HASHBYTES('SHA2_256',
    (SELECT * FROM dbo.Form WHERE Id IN ('$oldFormId', '$trueFormId') ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES));
EXEC sys.sp_addextendedproperty @name = N'AfifeTest:PreviousProductionBeforeBlockedDown', @value = @BeforeDown;
"@
    Invoke-PreviousProductionMigration $previousMigration -ExpectNullableDirectorBlock
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
IF COL_LENGTH(N'dbo.Form', N'previousProductionVersion') IS NULL
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Form') AND name = N'Director' AND is_nullable = 1)
    THROW 53589, N'Blocked Down changed the active flag or nullable Director schema.', 1;
DECLARE @BeforeDown varbinary(32) =
    (SELECT CONVERT(varbinary(32), value) FROM sys.extended_properties
     WHERE class = 0 AND name = N'AfifeTest:PreviousProductionBeforeBlockedDown');
IF @BeforeDown IS NULL OR @BeforeDown <> HASHBYTES('SHA2_256',
    (SELECT * FROM dbo.Form WHERE Id IN ('$oldFormId', '$trueFormId') ORDER BY Id FOR JSON PATH, INCLUDE_NULL_VALUES))
    THROW 53590, N'Blocked Down changed existing Form data.', 1;
PRINT N'PASS: incompatible NULL Director safely blocks Down without inventing data or changing the active schema.';
/* Only this disposable fixture is deliberately changed to an old-schema-compatible
   normal production; real NULL values must never be silently rewritten by Down. */
UPDATE dbo.Form SET previousProductionVersion = 0, Director = N'Retained normal director'
WHERE Id = '$trueFormId';
"@
    Invoke-PreviousProductionMigration $previousMigration
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
IF COL_LENGTH(N'dbo.Form', N'previousProductionVersion') IS NOT NULL
    THROW 53583, N'Down did not retire the active flag column.', 1;
DECLARE @Archive sysname =
    (SELECT columnRecord.name FROM sys.columns AS columnRecord
     JOIN sys.extended_properties AS sourceProperty
       ON sourceProperty.class = 1 AND sourceProperty.major_id = columnRecord.object_id
      AND sourceProperty.minor_id = columnRecord.column_id
      AND sourceProperty.name = N'Afife:ArchivedColumnSource'
     WHERE columnRecord.object_id = OBJECT_ID(N'dbo.Form')
       AND CONVERT(nvarchar(128), sourceProperty.value) = N'previousProductionVersion');
IF @Archive IS NULL THROW 53584, N'Down did not archive the flag values.', 1;
DECLARE @Verify nvarchar(max) = N'IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @Old AND '
    + QUOTENAME(@Archive) + N' = 0) OR NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = @New AND '
    + QUOTENAME(@Archive) + N' = 0) THROW 53585, N''Archived compatible flags were changed.'', 1;';
EXEC sys.sp_executesql @Verify, N'@Old uniqueidentifier, @New uniqueidentifier',
    @Old = '$oldFormId', @New = '$trueFormId';
PRINT N'PASS: Down archived old-schema-compatible false values on their original rows.';
"@
    Invoke-PreviousProductionMigration $targetMigration
    Invoke-PreviousProductionSql @"
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = '$oldFormId' AND previousProductionVersion = 0)
   OR NOT EXISTS (SELECT 1 FROM dbo.Form WHERE Id = '$trueFormId' AND previousProductionVersion = 0 AND Director = N'Retained normal director')
    THROW 53586, N'Up did not restore compatible flags and the unchanged director.', 1;
IF EXISTS (SELECT 1 FROM sys.extended_properties
    WHERE major_id = OBJECT_ID(N'dbo.Form') AND name = N'Afife:ArchivedColumnSource'
      AND CONVERT(nvarchar(128), value) = N'previousProductionVersion')
    THROW 53587, N'Up left the flag archive instead of restoring its original values.', 1;
PRINT N'PASS: Up restored compatible flags and original non-NULL director without replacing values.';
"@
    Write-Host "Previous-production Form Up/Down/Up regression passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    if ($databaseCreated) {
        Assert-PreviousProductionDatabase
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable previous-production database cleanup failed: $databaseName" }
    }
    Pop-Location
}
