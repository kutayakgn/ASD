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
$schemaSource = Join-Path $PSScriptRoot '27.08.2026_guncel_db_schema_script.sql'
$databaseName = 'YkbAfifeCurrentSchemaTest_' + ([Guid]::NewGuid().ToString('N'))
$temporarySchema = Join-Path $env:TEMP ($databaseName + '.sql')
$server = '(localdb)\MSSQLLocalDB'
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$previousUrls = $env:ASPNETCORE_URLS
$application = $null
$stdoutPath = Join-Path $env:TEMP ($databaseName + '.stdout.log')
$stderrPath = Join-Path $env:TEMP ($databaseName + '.stderr.log')

if ($databaseName -notmatch '^YkbAfifeCurrentSchemaTest_[a-f0-9]{32}$') {
    throw 'Disposable current-schema database name validation failed.'
}

Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable current-schema database creation failed.' }

    $schema = Get-Content -Raw -Encoding utf8 $schemaSource
    $bodyStart = $schema.IndexOf("USE [YkbAfife]`r`nGO", [StringComparison]::OrdinalIgnoreCase)
    if ($bodyStart -lt 0) {
        $bodyStart = $schema.IndexOf("USE [YkbAfife]`nGO", [StringComparison]::OrdinalIgnoreCase)
    }
    if ($bodyStart -lt 0) { throw 'Current schema body marker was not found.' }
    $schemaBody = $schema.Substring($bodyStart)
    $schemaBody = [regex]::Replace(
        $schemaBody,
        '(?im)^USE \[YkbAfife\]\s*$\s*^GO\s*$',
        "USE [$databaseName]`r`nGO",
        1)
    $schemaBody = [regex]::Replace(
        $schemaBody,
        '(?ims)^USE \[master\]\s*$\s*^GO\s*$.*$',
        '')
    [IO.File]::WriteAllText(
        $temporarySchema,
        $schemaBody,
        [Text.UTF8Encoding]::new($true))

    sqlcmd -I -S $server -d $databaseName -b -i $temporarySchema
    if ($LASTEXITCODE -ne 0) { throw '27.08 current schema fixture creation failed.' }

    $sentinelId = 'AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB'
    $sentinelSql = @"
INSERT INTO dbo.Form
(
    Id, ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName,
    TheatreName, PremiereDate, Display, ApplicantName, ApplicantRole,
    Phone, Email, Director, ContactName, ContactPhone,
    IsPublished, IsActive
)
VALUES
(
    '$sentinelId', N'CUR001', SYSDATETIME(), SYSDATETIME(),
    N'Korunacak Oyun', N'Korunacak Tiyatro', CONVERT(date, SYSDATETIME()),
    N'[]', N'Başvuran', N'Yetkili', N'5550000000',
    N'sentinel@example.invalid', N'Yönetmen', N'İletişim', N'5550000000', 1, 1
);
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $sentinelSql
    if ($LASTEXITCODE -ne 0) { throw 'Current-schema sentinel data creation failed.' }

    $env:ConnectionStrings__AfifeConnectionString = $connectionString
    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Current schema baseline adoption failed.' }

    $verification = @"
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
    THROW 53200, N'Current database migration history does not match the source migration chain.', 1;
END;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories
    WHERE CategoryCode = 1011
      AND CategoryName = N'Yılın En Başarılı Hareket Tasarımı (Kareografisi)'
      AND IsPublished = 1
)
    THROW 53204, N'Category 1011 name does not match the current canonical definition.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.Form
    WHERE Id = '$sentinelId'
      AND ApplicationNumber = N'CUR001'
      AND RepertoireName = N'Korunacak Oyun'
)
    THROW 53201, N'Existing Form data was not preserved.', 1;

IF OBJECT_ID(N'dbo.JuryPasswordResetTokens', N'U') IS NULL
   OR OBJECT_ID(N'dbo.usp_SynchronizeFormsToPlays', N'P') IS NULL
   OR OBJECT_ID(N'dbo.TR_Form_NormalizeSeasonAndSynchronize', N'TR') IS NULL
    THROW 53202, N'Canonical current-schema objects are missing.', 1;

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
    THROW 53203, N'Obsolete unique candidate indexes survived adoption.', 1;
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $verification
    if ($LASTEXITCODE -ne 0) { throw 'Current schema adoption verification failed.' }

    $env:ASPNETCORE_URLS = 'http://127.0.0.1:0'
    $application = Start-Process dotnet `
        -ArgumentList @(
            ('"{0}"' -f (Join-Path (Split-Path -Parent $project) "bin/$Configuration/net8.0/YKBAfife.dll"))
        ) `
        -WorkingDirectory (Split-Path -Parent $project) `
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
        throw "Current-schema application validation failed.`n$startupOutput`n$startupError"
    }

    Write-Host "Current 27.08 schema adoption passed for $databaseName."
}
finally {
    if ($null -ne $application -and -not $application.HasExited) {
        Stop-Process -Id $application.Id -Force -ErrorAction SilentlyContinue
        $application.WaitForExit()
    }
    $env:ConnectionStrings__AfifeConnectionString = $previousConnection
    $env:ASPNETCORE_URLS = $previousUrls
    Remove-Item -LiteralPath $temporarySchema -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    sqlcmd -I -S $server -d master -b -Q `
        "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
    Pop-Location
}
