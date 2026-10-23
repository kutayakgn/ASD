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
$versionRoot = Join-Path $repositoryRoot 'src/YKBAfife/Migrations/Versions'
. (Join-Path $PSScriptRoot 'migration-sql.ps1')
$migrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name | ForEach-Object { $_.BaseName })
if ($migrationIds.Count -lt 2) { throw 'Workload rollback test requires at least two source migrations.' }
$latestMigration = $migrationIds[-1]

# Locate the first frozen workload API, rather than assuming the latest schema
# migration introduced it. Later unrelated migrations must not break this test.
$workloadIndex = -1
for ($index = 0; $index -lt $migrationIds.Count; $index++) {
    $logicalName = $migrationIds[$index] -replace '^\d{14}_', ''
    $upSql = Read-AfifeSqlSection $versionRoot $logicalName 'UP'
    if ($upSql -match '(?is)CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[?dbo\]?\.\[?usp_RefreshRankings\]?\s+@CategoryCodesJson\b') {
        $workloadIndex = $index
        break
    }
}
if ($workloadIndex -lt 1) { throw 'A frozen incremental workload migration and its predecessor are required.' }
$workloadMigration = $migrationIds[$workloadIndex]
$previousMigration = $migrationIds[$workloadIndex - 1]
$databaseName = 'YkbAfifeWorkloadTest_' + [Guid]::NewGuid().ToString('N')
$connectionString = "Server=$Server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$databaseCreated = $false

function Assert-WorkloadTestDatabaseName {
    if ($databaseName -notmatch '^YkbAfifeWorkloadTest_[a-f0-9]{32}$') {
        throw "Refusing an unvalidated disposable database: $databaseName"
    }
}

function Invoke-WorkloadMigration([string] $Target) {
    dotnet tool run dotnet-ef database update $Target `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw "Workload migration to $Target failed." }
}

function Invoke-WorkloadSqlTests {
    $failures = @()
    foreach ($fileName in @('test-db-workload-scope.sql', 'test-reverse-sync-scope.sql', 'test-season-workload-scope.sql')) {
        $testPath = Join-Path $PSScriptRoot $fileName
        sqlcmd -I -S $Server -d $databaseName -b -f 65001 -l 30 -t 180 -i $testPath
        if ($LASTEXITCODE -ne 0) { $failures += $fileName }
    }
    if ($failures.Count -gt 0) { throw "Workload SQL regressions failed: $($failures -join ', ')" }
}

Push-Location $repositoryRoot
try {
    Assert-WorkloadTestDatabaseName
    sqlcmd -I -S $Server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53359, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Workload disposable database creation failed.' }
    $databaseCreated = $true
    $env:ConnectionStrings__AfifeConnectionString = $connectionString

    Invoke-WorkloadMigration $latestMigration
    Invoke-WorkloadSqlTests
    Invoke-WorkloadMigration $previousMigration
    $downVerification = @"
IF EXISTS
(
    SELECT 1 FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.usp_RefreshRankings')
      AND name IN (N'@CategoryCodesJson', N'@CandidateIdsJson')
)
    THROW 53360, N'Workload Down did not restore the previous ranking procedure API.', 1;
"@
    sqlcmd -I -S $Server -d $databaseName -b -l 30 -t 180 -Q $downVerification
    if ($LASTEXITCODE -ne 0) { throw 'Workload migration Down verification failed.' }

    Invoke-WorkloadMigration $workloadMigration
    Invoke-WorkloadSqlTests
    if ($latestMigration -ne $workloadMigration) {
        Invoke-WorkloadMigration $latestMigration
        Invoke-WorkloadSqlTests
    }
    Write-Host "Database workload Up/Down/Up regression passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    if ($databaseCreated) {
        Assert-WorkloadTestDatabaseName
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable workload database cleanup failed: $databaseName" }
    }
    Pop-Location
}
