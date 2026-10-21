param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',
    [string] $Server = $(if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' })
)

$ErrorActionPreference = 'Stop'
if ($env:AFIFE_TEST_SQL_SERVER -and
    $env:AFIFE_TEST_SQL_SERVER -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.'
}
if ($Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'Server must name a local SQL Server LocalDB instance.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationRoot = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'
$migrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name |
    ForEach-Object { $_.BaseName })
if ($migrationIds.Count -lt 2) { throw 'Scoped synchronization rollback test requires at least two source migrations.' }
$latestMigration = $migrationIds[-1]
$previousMigration = $migrationIds[-2]
$databaseName = 'YkbAfifeScopedFormTest_' + [Guid]::NewGuid().ToString('N')
$connectionString = "Server=$Server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$databaseCreated = $false

function Assert-ScopedTestDatabaseName {
    if ($databaseName -notmatch '^YkbAfifeScopedFormTest_[a-f0-9]{32}$') {
        throw "Refusing an unvalidated disposable database: $databaseName"
    }
}

function Invoke-ScopedMigration([string] $Target) {
    dotnet tool run dotnet-ef database update $Target `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw "Scoped Form migration to $Target failed." }
}

function Invoke-ScopedSqlTest([string] $FileName) {
    $testPath = Join-Path $PSScriptRoot $FileName
    sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -i $testPath
    if ($LASTEXITCODE -ne 0) { throw "Scoped Form SQL regression failed: $FileName" }
}

Push-Location $repositoryRoot
try {
    Assert-ScopedTestDatabaseName
    sqlcmd -I -S $Server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53299, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Scoped Form disposable database creation failed.' }
    $databaseCreated = $true
    $env:ConnectionStrings__AfifeConnectionString = $connectionString

    Invoke-ScopedMigration $latestMigration
    Invoke-ScopedSqlTest 'test-scoped-form-sync.sql'

    # Verify that Down restores the previous procedure API, then Up installs
    # the scoped behavior again rather than relying only on migration history.
    Invoke-ScopedMigration $previousMigration
    $downVerification = @"
IF EXISTS
(
    SELECT 1 FROM sys.parameters
    WHERE object_id IN (OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays'),
                        OBJECT_ID(N'dbo.usp_SynchronizeFormCandidates'))
      AND name = N'@FormIdsJson'
)
    THROW 53300, N'Scoped synchronization Down did not restore the previous procedure API.', 1;
"@
    sqlcmd -I -S $Server -d $databaseName -b -l 30 -t 180 -Q $downVerification
    if ($LASTEXITCODE -ne 0) { throw 'Scoped Form migration Down verification failed.' }

    Invoke-ScopedMigration $latestMigration
    Invoke-ScopedSqlTest 'test-scoped-form-sync.sql'
    Write-Host "Scoped Form synchronization Up/Down/Up regression passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    if ($databaseCreated) {
        Assert-ScopedTestDatabaseName
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable scoped Form database cleanup failed: $databaseName" }
    }
    Pop-Location
}
