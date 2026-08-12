param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$fixture = Join-Path $repositoryRoot 'scripts/test-company-upgrade-fixture.sql'
$databaseName = 'YkbAfifeUpgradeTest_' + ([Guid]::NewGuid().ToString('N'))

if ($databaseName -notmatch '^YkbAfifeUpgradeTest_[a-f0-9]{32}$') {
    throw 'Disposable database name validation failed.'
}

$server = '(localdb)\MSSQLLocalDB'
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString

Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database creation failed.' }

    $env:ConnectionStrings__AfifeConnectionString = $connectionString

    dotnet tool run dotnet-ef database update 20260812082231_ScopeUserEmailUniquenessByRole `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Pre-company migration setup failed.' }

    sqlcmd -I -S $server -d $databaseName -b -i $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Company fixture creation failed.' }

    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Company-style upgrade failed.' }

    $verification = @"
IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode'
)
    THROW 52980, N'Obsolete company candidate index still exists.', 1;

IF
(
    SELECT COUNT(*) FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1006
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 52981, N'Both category 1006 candidates were not synchronized.', 1;

IF
(
    SELECT COUNT(DISTINCT RoleCode) FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1006
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 52982, N'Category 1006 candidates do not have unique RoleCodes.', 1;
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $verification
    if ($LASTEXITCODE -ne 0) { throw 'Upgraded database verification failed.' }

    Write-Host "Company-style migration upgrade passed for $databaseName."
}
finally {
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    sqlcmd -I -S $server -d master -b -Q `
        "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
    Pop-Location
}
