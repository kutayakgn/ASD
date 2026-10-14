param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationRoot = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'
$expectedMigrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name |
    ForEach-Object { $_.BaseName })
if ($expectedMigrationIds.Count -eq 0) { throw 'No source migrations were found.' }
$expectedMigrationValues = ($expectedMigrationIds | ForEach-Object { "(N'$_')" }) -join ",`n"
$fixture = Join-Path $repositoryRoot 'scripts/test-oldest-preprod-fixture.sql'
$databaseName = 'YkbAfifeOldestPreprodTest_' + ([Guid]::NewGuid().ToString('N'))

if ($databaseName -notmatch '^YkbAfifeOldestPreprodTest_[a-f0-9]{32}$') {
    throw 'Disposable oldest-preprod database name validation failed.'
}

$server = '(localdb)\MSSQLLocalDB'
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$previousUrls = $env:ASPNETCORE_URLS
$application = $null

Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable oldest-preprod database creation failed.' }

    sqlcmd -I -S $server -d $databaseName -b -i $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Oldest-preprod fixture creation failed.' }

    $env:ConnectionStrings__AfifeConnectionString = $connectionString
    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Oldest-preprod migration upgrade failed.' }

    $verification = @"
IF
(
    SELECT COUNT(*) FROM dbo.AwardCategories
    WHERE CategoryCode BETWEEN 1001 AND 1011 AND IsPublished = 1
) <> 11
    THROW 53100, N'Canonical AwardCategories were not fully created.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.AwardCategories
    WHERE CategoryCode BETWEEN 1001 AND 1011
      AND
      (
          MultiCandidate <> CASE WHEN CategoryCode BETWEEN 1003 AND 1011 THEN 1 ELSE 0 END
          OR HasRoleAndPhoto <> CASE WHEN CategoryCode BETWEEN 1002 AND 1011 THEN 1 ELSE 0 END
      )
)
    THROW 53101, N'AwardCategories flags were not normalized.', 1;

DECLARE @ExpectedMigrations TABLE (MigrationId nvarchar(150) PRIMARY KEY);
INSERT INTO @ExpectedMigrations (MigrationId) VALUES
$expectedMigrationValues;

IF EXISTS (SELECT MigrationId FROM @ExpectedMigrations EXCEPT SELECT MigrationId FROM dbo.__EFMigrationsHistory)
   OR EXISTS (SELECT MigrationId FROM dbo.__EFMigrationsHistory EXCEPT SELECT MigrationId FROM @ExpectedMigrations)
BEGIN
    SELECT N'Expected' AS MigrationSource, MigrationId FROM @ExpectedMigrations
    UNION ALL
    SELECT N'Applied' AS MigrationSource, MigrationId FROM dbo.__EFMigrationsHistory
    ORDER BY MigrationSource, MigrationId;
    THROW 53102, N'Oldest-preprod database migration history does not match the source migration chain.', 1;
END;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories
    WHERE CategoryCode = 1011
      AND CategoryName = N'Yılın En Başarılı Hareket Tasarımı (Kareografisi)'
      AND IsPublished = 1
)
    THROW 53104, N'Category 1011 name does not match the current canonical definition.', 1;

IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name IN
      (
          N'UX_PlayAwardCategories_Current_Play_Category_Role',
          N'UX_PlayAwardCategories_FormSourceSlot'
      )
)
    THROW 53103, N'Obsolete candidate indexes were recreated.', 1;
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $verification
    if ($LASTEXITCODE -ne 0) { throw 'Oldest-preprod database verification failed.' }

    $stdoutPath = Join-Path $env:TEMP ($databaseName + '.stdout.log')
    $stderrPath = Join-Path $env:TEMP ($databaseName + '.stderr.log')
    $env:ASPNETCORE_URLS = 'http://127.0.0.1:0'
    $application = Start-Process dotnet `
        -ArgumentList @(
            'run', '--project', $project, '--configuration', $Configuration,
            '--no-build', '--no-launch-profile'
        ) `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    $startupValidated = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 250
        if (Test-Path $stdoutPath) {
            $startupOutput = Get-Content $stdoutPath -Raw
            if ($startupOutput -match 'Database schema validation completed successfully') {
                $startupValidated = $true
                break
            }
        }
        if ($application.HasExited) { break }
    }

    if (-not $application.HasExited) {
        Stop-Process -Id $application.Id -Force
        $application.WaitForExit()
    }

    if (-not $startupValidated) {
        $startupOutput = if (Test-Path $stdoutPath) { Get-Content $stdoutPath -Raw } else { '' }
        $startupError = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { '' }
        throw "Oldest-preprod application startup failed.`n$startupOutput`n$startupError"
    }

    Write-Host "Oldest-preprod migration upgrade passed for $databaseName."
}
finally {
    if ($null -ne $application -and -not $application.HasExited) {
        Stop-Process -Id $application.Id -Force -ErrorAction SilentlyContinue
        $application.WaitForExit()
    }
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    $env:ASPNETCORE_URLS = $previousUrls
    Remove-Item -LiteralPath (Join-Path $env:TEMP ($databaseName + '.stdout.log')) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $env:TEMP ($databaseName + '.stderr.log')) -Force -ErrorAction SilentlyContinue
    sqlcmd -I -S $server -d master -b -Q `
        "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
    Pop-Location
}
