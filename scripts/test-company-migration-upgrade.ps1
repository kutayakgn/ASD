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
$fixture = Join-Path $repositoryRoot 'scripts/test-company-upgrade-fixture.sql'
$databaseName = 'YkbAfifeUpgradeTest_' + ([Guid]::NewGuid().ToString('N'))

if ($databaseName -notmatch '^YkbAfifeUpgradeTest_[a-f0-9]{32}$') {
    throw 'Disposable database name validation failed.'
}

$server = '(localdb)\MSSQLLocalDB'
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$previousConnection = $env:ConnectionStrings__AfifeConnectionString
$previousUrls = $env:ASPNETCORE_URLS
$application = $null

Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database creation failed.' }

    $env:ConnectionStrings__AfifeConnectionString = $connectionString

    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Canonical company fixture setup failed.' }

    sqlcmd -I -S $server -d $databaseName -b -Q @"
IF OBJECT_ID(N'dbo.CK_Users_Username_InstagramFormat', N'C') IS NOT NULL
    ALTER TABLE dbo.Users DROP CONSTRAINT CK_Users_Username_InstagramFormat;
"@
    if ($LASTEXITCODE -ne 0) { throw 'Legacy company constraint setup failed.' }

    sqlcmd -I -S $server -d $databaseName -b -i $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Company fixture creation failed.' }

    sqlcmd -I -S $server -d $databaseName -b -Q @"
DELETE FROM dbo.__EFMigrationsHistory;
INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
VALUES (N'20260812082231_ScopeUserEmailUniquenessByRole', N'8.0.29');
"@
    if ($LASTEXITCODE -ne 0) { throw 'Legacy company migration history setup failed.' }

    dotnet tool run dotnet-ef database update `
        --project $project --startup-project $project `
        --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Company-style upgrade failed.' }

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
    THROW 53007, N'Company database migration history does not match the source migration chain.', 1;
END;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories
    WHERE CategoryCode = 1011
      AND CategoryName = N'Yılın En Başarılı Hareket Tasarımı (Kareografisi)'
      AND IsPublished = 1
)
    THROW 53008, N'Category 1011 name does not match the current canonical definition.', 1;

IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode'
)
    THROW 52980, N'Obsolete company candidate index still exists.', 1;

IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_Current_Play_Category_Role'
)
    THROW 53000, N'Invalid unique current-role candidate index still exists.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'IX_PlayAwardCategories_Current_Play_Category_Role'
      AND is_unique = 0
)
    THROW 53001, N'Non-unique current-role candidate lookup index is missing.', 1;

IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_FormSourceSlot'
)
    THROW 53004, N'Invalid unique Form source-slot index still exists.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'IX_PlayAwardCategories_FormSourceSlot'
      AND is_unique = 0
)
    THROW 53005, N'Non-unique Form source-slot lookup index is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS candidateIndex
    WHERE candidateIndex.object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND candidateIndex.name = N'UX_PlayAwardCategories_Play_Category_Role_Candidate'
      AND candidateIndex.is_unique = 1
      AND
      (
          SELECT COUNT(*)
          FROM sys.index_columns AS indexColumn
          WHERE indexColumn.object_id = candidateIndex.object_id
            AND indexColumn.index_id = candidateIndex.index_id
            AND indexColumn.key_ordinal > 0
      ) = 4
      AND EXISTS
      (
          SELECT 1 FROM sys.index_columns AS indexColumn
          INNER JOIN sys.columns AS columnRecord
              ON columnRecord.object_id = indexColumn.object_id
             AND columnRecord.column_id = indexColumn.column_id
          WHERE indexColumn.object_id = candidateIndex.object_id
            AND indexColumn.index_id = candidateIndex.index_id
            AND indexColumn.key_ordinal = 1 AND columnRecord.name = N'PlayId'
      )
      AND EXISTS
      (
          SELECT 1 FROM sys.index_columns AS indexColumn
          INNER JOIN sys.columns AS columnRecord
              ON columnRecord.object_id = indexColumn.object_id
             AND columnRecord.column_id = indexColumn.column_id
          WHERE indexColumn.object_id = candidateIndex.object_id
            AND indexColumn.index_id = candidateIndex.index_id
            AND indexColumn.key_ordinal = 2 AND columnRecord.name = N'AwardCategoryCode'
      )
      AND EXISTS
      (
          SELECT 1 FROM sys.index_columns AS indexColumn
          INNER JOIN sys.columns AS columnRecord
              ON columnRecord.object_id = indexColumn.object_id
             AND columnRecord.column_id = indexColumn.column_id
          WHERE indexColumn.object_id = candidateIndex.object_id
            AND indexColumn.index_id = candidateIndex.index_id
            AND indexColumn.key_ordinal = 3 AND columnRecord.name = N'RoleCode'
      )
      AND EXISTS
      (
          SELECT 1 FROM sys.index_columns AS indexColumn
          INNER JOIN sys.columns AS columnRecord
              ON columnRecord.object_id = indexColumn.object_id
             AND columnRecord.column_id = indexColumn.column_id
          WHERE indexColumn.object_id = candidateIndex.object_id
            AND indexColumn.index_id = candidateIndex.index_id
            AND indexColumn.key_ordinal = 4 AND columnRecord.name = N'Candidate'
      )
)
    THROW 53003, N'Four-field candidate uniqueness index does not match the required contract.', 1;

IF
(
    SELECT COUNT(*) FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1004
      AND RoleCode = 17
      AND Id IN
      (
          '99999999-9999-9999-9999-999999999993',
          '99999999-9999-9999-9999-999999999994'
      )
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 53002, N'Different candidates sharing a RoleCode were not preserved.', 1;

IF
(
    SELECT COUNT(DISTINCT SourceFormCandidateOrder)
    FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1004
      AND Id IN
      (
          '99999999-9999-9999-9999-999999999993',
          '99999999-9999-9999-9999-999999999994'
      )
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 53006, N'Duplicate legacy Form source slots were not repaired uniquely.', 1;

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

IF
(
    SELECT COUNT(*) FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1005
      AND Candidate = N'deneme'
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 52998, N'Duplicate legacy RoleCode repair did not preserve both Form slots.', 1;

IF
(
    SELECT COUNT(DISTINCT RoleCode) FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1005
      AND Candidate = N'deneme'
      AND IsPublished = 1 AND IsCurrent = 1
) <> 2
    THROW 52999, N'Duplicate legacy RoleCodes were not reassigned uniquely.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE candidate.PlayId = '44444444-4444-4444-4444-444444444444'
      AND (vote.IsPublished = 1 OR vote.IsActive = 1)
)
    THROW 52983, N'Inactive Form legacy vote was not normalized.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE Id = '55555555-5555-5555-5555-555555555555'
      AND (IsPublished = 1 OR IsActive = 1)
)
    THROW 52984, N'Inactive Form legacy director was not normalized.', 1;

IF EXISTS (SELECT 1 FROM dbo.AwardCategories WHERE CategoryCode = 1012 AND IsPublished = 1)
    THROW 52985, N'Retired category 1012 is still published.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.PlayAwardCategories
    WHERE AwardCategoryCode = 1012
      AND (IsPublished = 1 OR IsActive = 1 OR IsCurrent = 1)
)
    THROW 52986, N'Retired category 1012 still has a visible/current candidate.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.JuryVotes
    WHERE PlayAwardCategoryId = '77777777-7777-7777-7777-777777777777'
      AND (IsPublished = 1 OR IsActive = 1)
)
    THROW 52987, N'Retired category 1012 still has a visible vote.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.Rankings
    WHERE PlayAwardCategoryId = '77777777-7777-7777-7777-777777777777'
      AND IsPublished = 1
)
    THROW 52988, N'Retired category 1012 still has a visible ranking.', 1;

IF EXISTS (SELECT 1 FROM dbo.Images WHERE Id = '88888888-8888-8888-8888-888888888888' AND IsPublished = 1)
    THROW 52989, N'Retired category 1012 orphan image is still published.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.Images AS image ON image.Id = candidate.PhotoImageId
    WHERE candidate.PlayId = '22222222-2222-2222-2222-222222222222'
      AND candidate.AwardCategoryCode = 1006
      AND candidate.SourceFormCandidateOrder = 1
      AND candidate.IsPublished = 1
      AND image.IsPublished = 1
      AND image.ContentType = N'image/png'
      AND DATALENGTH(image.ImageData) > 4000
)
    THROW 52990, N'Form Base64 photo above 4000 characters was not materialized.', 1;

UPDATE dbo.Plays
SET PlayName = N'PlayToForm Sync Name',
    TheaterName = N'PlayToForm Sync Theater',
    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
WHERE Id = '22222222-2222-2222-2222-222222222222';

IF NOT EXISTS
(
    SELECT 1 FROM dbo.Form
    WHERE Id = '11111111-1111-1111-1111-111111111111'
      AND RepertoireName = N'PlayToForm Sync Name'
      AND TheatreName = N'PlayToForm Sync Theater'
)
    THROW 52991, N'Play changes were not synchronized back to Form.', 1;

UPDATE dbo.Form
SET RepertoireName = N'FormToPlay Sync Name',
    TheatreName = N'FormToPlay Sync Theater',
    UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
WHERE Id = '11111111-1111-1111-1111-111111111111';

IF NOT EXISTS
(
    SELECT 1 FROM dbo.Plays
    WHERE Id = '22222222-2222-2222-2222-222222222222'
      AND PlayName = N'FormToPlay Sync Name'
      AND TheaterName = N'FormToPlay Sync Theater'
)
    THROW 52992, N'Form changes were not synchronized to Play.', 1;

DECLARE @AdminPhotoId uniqueidentifier = '99999999-9999-9999-9999-999999999999';
INSERT INTO dbo.Images
(
    Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished
)
VALUES
(
    @AdminPhotoId, N'admin-photo.png', N'image/png',
    0x89504E470D0A1A0A4146494645,
    DATEADD(HOUR, 3, SYSUTCDATETIME()),
    '66666666-6666-6666-6666-666666666666', 1
);

DECLARE @EditedCandidateId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM dbo.PlayAwardCategories
    WHERE PlayId = '22222222-2222-2222-2222-222222222222'
      AND AwardCategoryCode = 1006
      AND SourceFormCandidateOrder = 1
      AND IsPublished = 1
      AND IsCurrent = 1
);

UPDATE dbo.PlayAwardCategories
SET Candidate = N'CandidateToForm Sync Name',
    PhotoImageId = @AdminPhotoId,
    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
WHERE Id = @EditedCandidateId;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Form AS formRecord
    CROSS APPLY OPENJSON(formRecord.SupportActor)
    WITH
    (
        [Name] nvarchar(250) N'$.Name',
        ImageUrl nvarchar(255) N'$.ImageUrl',
        Base64 nvarchar(max) N'$.Base64'
    ) AS candidate
    WHERE formRecord.Id = '11111111-1111-1111-1111-111111111111'
      AND candidate.[Name] = N'CandidateToForm Sync Name'
      AND candidate.ImageUrl = N'admin-photo.png'
      AND LEN(candidate.Base64) > 10
)
    THROW 52993, N'Candidate name/photo changes were not synchronized back to Form.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AdminLogs
    WHERE TableName = N'Plays'
      AND OldValues IS NOT NULL AND NewValues IS NOT NULL
      AND NewValues LIKE N'%PlayToForm Sync Name%'
)
    THROW 52994, N'Play old/new audit detail was not written.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AdminLogs
    WHERE TableName = N'Form'
      AND OldValues IS NOT NULL AND NewValues IS NOT NULL
      AND NewValues LIKE N'%FormToPlay Sync Name%'
)
    THROW 52995, N'Form old/new audit detail was not written.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.AdminLogs
    WHERE TableName = N'PlayAwardCategories'
      AND OldValues IS NOT NULL AND NewValues IS NOT NULL
      AND NewValues LIKE N'%CandidateToForm Sync Name%'
)
    THROW 52996, N'Candidate old/new audit detail was not written.', 1;

DECLARE @NonImageWasRejected bit = 0;
BEGIN TRY
    INSERT INTO dbo.Images
    (
        Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished
    )
    VALUES
    (
        'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA', N'zararli-dosya.png',
        N'image/png', 0x3C7363726970743E,
        DATEADD(HOUR, 3, SYSUTCDATETIME()),
        '66666666-6666-6666-6666-666666666666', 1
    );
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52432
        SET @NonImageWasRejected = 1;
    ELSE
        THROW;
END CATCH;

IF @NonImageWasRejected = 0
    THROW 52997, N'Non-image bytes were accepted by dbo.Images.', 1;

EXEC dbo.usp_RefreshRankings;
"@
    sqlcmd -I -S $server -d $databaseName -b -Q $verification
    if ($LASTEXITCODE -ne 0) { throw 'Upgraded database verification failed.' }

    $stdoutPath = Join-Path $env:TEMP ($databaseName + '.stdout.log')
    $stderrPath = Join-Path $env:TEMP ($databaseName + '.stderr.log')
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
        throw "Application startup/schema validation failed.`n$startupOutput`n$startupError"
    }

    Write-Host "Company-style migration upgrade passed for $databaseName."
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
