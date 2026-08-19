param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$databaseName = 'YkbAfifeEmptyTest_' + ([Guid]::NewGuid().ToString('N'))

if ($databaseName -notmatch '^YkbAfifeEmptyTest_[a-f0-9]{32}$') {
    throw 'Disposable empty database name validation failed.'
}

$server = '(localdb)\MSSQLLocalDB'
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString

Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable empty database creation failed.' }

    $env:ConnectionStrings__AfifeConnectionString = $connectionString
    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Empty database migration failed.' }

    $verification = @"
IF NOT EXISTS
(
    SELECT 1 FROM dbo.__EFMigrationsHistory
    WHERE MigrationId = N'20260819113000_V1_2_6_RepairFormSourceSlotContract'
)
    THROW 53110, N'Latest migration was not recorded on the empty database.', 1;

IF OBJECT_ID(N'dbo.Form', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Images', N'U') IS NULL
   OR OBJECT_ID(N'dbo.AdminLogs', N'U') IS NULL
    THROW 53111, N'Canonical tables were not created on the empty database.', 1;

IF (SELECT COUNT(*) FROM dbo.AwardCategories WHERE IsPublished = 1) <> 11
    THROW 53112, N'Canonical award categories were not created on the empty database.', 1;

IF OBJECT_ID(N'dbo.usp_RefreshRankings', N'P') IS NULL
    THROW 53113, N'Programmability objects were not created on the empty database.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_Play_Category_Role_Candidate'
      AND is_unique = 1
)
    THROW 53114, N'Candidate uniqueness contract is missing on the empty database.', 1;
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $verification
    if ($LASTEXITCODE -ne 0) { throw 'Empty database verification failed.' }

    Write-Host "Empty database migration passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    sqlcmd -I -S $server -d master -b -Q `
        "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
    Pop-Location
}
