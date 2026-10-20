param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',
    [string] $Server = '(localdb)\MSSQLLocalDB'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectDirectory = Join-Path $repositoryRoot 'src/YKBAfife'
$applicationDll = Join-Path $projectDirectory "bin/$Configuration/net8.0/YKBAfife.dll"
$fixture = Join-Path $PSScriptRoot 'test-legacy-form-upgrade-fixture.sql'
$migrationRoot = Join-Path $projectDirectory 'Data/Migrations'
$expectedMigrationIds = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
    Where-Object { $_.Name -cmatch '^\d{14}_[A-Za-z0-9_]+\.cs$' } |
    Sort-Object Name |
    ForEach-Object { $_.BaseName })
if ($expectedMigrationIds.Count -eq 0) { throw 'No source migrations were found.' }
if (-not (Test-Path -LiteralPath $applicationDll)) { throw "Build the application before this test: $applicationDll" }
$expectedMigrationValues = ($expectedMigrationIds | ForEach-Object { "(N'$_')" }) -join ",`n"

# Compare SQL binary values rather than culture-sensitive PowerShell strings or
# SQL text equality (which ignores trailing spaces). EXCEPT also distinguishes NULL.
$originalFormColumns = @(
    'Id', 'ApplicationNumber', 'SeasonId', 'CreatedDate', 'UpdatedDate',
    'RepertoireName', 'TheatreName', 'PremiereDate', 'Display', 'ApplicantName',
    'ApplicantRole', 'Phone', 'Email', 'Director', 'ContactName', 'ContactPhone',
    'LeadActress', 'LeadActor', 'SupportActress', 'SupportActor', 'StageDesign',
    'ClothesDesign', 'LightDesign', 'StageMusic', 'Choreography', 'Active', 'Deleted'
)
$copiedFormColumns = @($originalFormColumns | Where-Object { $_ -notin @('Id', 'SeasonId', 'Active', 'Deleted') })
$managerColumns = @('Id', 'FullName', 'Email', 'Password', 'CreatedDate', 'UpdatedDate')
$logColumns = @('Id', 'Title', 'Source', 'EventType', 'Message', 'CreatedDate')
$historyColumns = @('MigrationId', 'ProductVersion')
$createdDatabases = [System.Collections.Generic.List[string]]::new()
$logPaths = [System.Collections.Generic.List[string]]::new()
$application = $null
$environmentNames = @('ConnectionStrings__AfifeConnectionString', 'ASPNETCORE_URLS', 'ASPNETCORE_ENVIRONMENT', 'DOTNET_ENVIRONMENT')
$previousEnvironment = @{}
foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name) }

function Assert-DisposableDatabaseName([string] $Database) {
    if ($Database -notmatch '^YkbAfifeLegacyFormTest_[a-f0-9]{32}(_Original)?$') {
        throw "Refusing to create or remove an unvalidated disposable database: $Database"
    }
}

function Invoke-LegacySql([string] $Database, [string] $Query) {
    sqlcmd -I -S $Server -d $Database -b -l 30 -t 180 -Q $Query
    if ($LASTEXITCODE -ne 0) { throw "Legacy Form regression SQL failed in $Database." }
}

function Get-BinaryProjection([string[]] $Columns) {
    return (($Columns | ForEach-Object { "CONVERT(varbinary(max), [$_])" }) -join ', ')
}

function Get-ExactTableComparison([string] $OriginalDatabase, [string] $OriginalTable,
    [string] $CurrentTable, [string[]] $Columns) {
    $projection = Get-BinaryProjection $Columns
    return @"
IF (SELECT COUNT_BIG(*) FROM [$OriginalDatabase].dbo.[$OriginalTable])
   <> (SELECT COUNT_BIG(*) FROM dbo.[$CurrentTable])
   OR EXISTS
   (
       SELECT $projection FROM [$OriginalDatabase].dbo.[$OriginalTable]
       EXCEPT SELECT $projection FROM dbo.[$CurrentTable]
   )
   OR EXISTS
   (
       SELECT $projection FROM dbo.[$CurrentTable]
       EXCEPT SELECT $projection FROM [$OriginalDatabase].dbo.[$OriginalTable]
   )
    THROW 53200, N'Original $OriginalTable data changed in $CurrentTable (binary/NULL comparison).', 1;
"@
}

function Get-OriginalSchemaComparison([string] $OriginalDatabase, [bool] $Upgraded) {
    $formTable = if ($Upgraded) { 'FormLegacy_PreEf' } else { 'Form' }
    return @"
DECLARE @ActualColumns TABLE
(
    TableName sysname, ColumnName sysname, ColumnId int, TypeId int,
    MaxLength smallint, [Precision] tinyint, Scale tinyint, CollationName sysname NULL,
    IsNullable bit, IsIdentity bit, DefaultDefinition nvarchar(max) NULL
);
INSERT @ActualColumns
SELECT CASE WHEN t.name = N'$formTable' THEN N'Form' ELSE t.name END,
       c.name, c.column_id, c.system_type_id, c.max_length, c.precision, c.scale,
       c.collation_name, c.is_nullable, c.is_identity, defaults.definition
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
LEFT JOIN sys.default_constraints AS defaults ON defaults.object_id = c.default_object_id
WHERE s.name = N'dbo' AND t.name IN (N'$formTable', N'Manager', N'Log')
  AND EXISTS
  (
      SELECT 1 FROM [$OriginalDatabase].dbo.OriginalColumnDefinitions AS original
      WHERE original.TableName = CASE WHEN t.name = N'$formTable' THEN N'Form' ELSE t.name END
        AND original.ColumnName = c.name
  );
IF EXISTS
(
    SELECT * FROM [$OriginalDatabase].dbo.OriginalColumnDefinitions
    EXCEPT SELECT * FROM @ActualColumns
)
OR EXISTS
(
    SELECT * FROM @ActualColumns
    EXCEPT SELECT * FROM [$OriginalDatabase].dbo.OriginalColumnDefinitions
)
    THROW 53201, N'An original Form/Manager/Log column definition changed.', 1;
"@
}

function Invoke-ProductionStartup([string] $Database, [string] $RunName, [bool] $ExpectDuplicateFailure = $false) {
    $env:ConnectionStrings__AfifeConnectionString = "Server=$Server;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True"
    $env:ASPNETCORE_URLS = 'http://127.0.0.1:0'
    $env:ASPNETCORE_ENVIRONMENT = 'Production'
    $env:DOTNET_ENVIRONMENT = 'Production'
    $stdoutPath = Join-Path $env:TEMP ($Database + '.' + $RunName + '.stdout.log')
    $stderrPath = Join-Path $env:TEMP ($Database + '.' + $RunName + '.stderr.log')
    $logPaths.Add($stdoutPath)
    $logPaths.Add($stderrPath)
    $script:application = Start-Process dotnet `
        -ArgumentList @(('"{0}"' -f $applicationDll)) `
        -WorkingDirectory $projectDirectory -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    $validated = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        Start-Sleep -Milliseconds 250
        if (Test-Path -LiteralPath $stdoutPath) {
            $output = Get-Content -LiteralPath $stdoutPath -Raw
            if ($output -match 'Database schema validation completed successfully') {
                $validated = $true
                break
            }
        }
        if ($application.HasExited) { break }
    } while ([DateTime]::UtcNow -lt $deadline)

    $exitedBeforeStop = $application.HasExited
    if (-not $application.HasExited) {
        Stop-Process -Id $application.Id -Force
        $application.WaitForExit()
    }
    $output = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { '' }
    $errorOutput = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
    if ($ExpectDuplicateFailure) {
        if ($validated -or -not $exitedBeforeStop -or
            ($output + $errorOutput) -notmatch 'duplicate published Form\.ApplicationNumber') {
            throw "Expected legacy duplicate preflight to stop startup in $Database.`n$output`n$errorOutput"
        }
    }
    elseif (-not $validated) {
        throw "Legacy Form production startup failed in $Database ($RunName).`n$output`n$errorOutput"
    }
}

Push-Location $repositoryRoot
try {
    foreach ($scenario in @('EmptyHistory', 'HistoricalHistory', 'DuplicatePublished')) {
        $database = 'YkbAfifeLegacyFormTest_' + [Guid]::NewGuid().ToString('N')
        $originalDatabase = $database + '_Original'
        foreach ($name in @($database, $originalDatabase)) {
            Assert-DisposableDatabaseName $name
            Invoke-LegacySql 'master' "CREATE DATABASE [$name];"
            $createdDatabases.Add($name)
        }
        sqlcmd -I -S $Server -d $database -b -f 65001 -i $fixture
        if ($LASTEXITCODE -ne 0) { throw 'Legacy production schema fixture creation failed.' }

        if ($scenario -eq 'HistoricalHistory') {
            Invoke-LegacySql $database @"
INSERT dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
VALUES (N'20240303121000_LegacyInitialCreate', N'6.0.0');
"@
        }
        if ($scenario -eq 'DuplicatePublished') {
            Invoke-LegacySql $database "UPDATE dbo.Form SET ApplicationNumber = N'000007' WHERE Id = 19;"
        }

        # Snapshot to a separate DB so the tested starting DB has precisely the
        # four production tables and its archive can be checked independently.
        Invoke-LegacySql $database @"
IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) <> 4
    THROW 53202, N'The starting legacy fixture must contain exactly four tables.', 1;
SELECT * INTO [$originalDatabase].dbo.Form FROM dbo.Form;
SELECT * INTO [$originalDatabase].dbo.Manager FROM dbo.Manager;
SELECT * INTO [$originalDatabase].dbo.Log FROM dbo.Log;
SELECT * INTO [$originalDatabase].dbo.__EFMigrationsHistory FROM dbo.__EFMigrationsHistory;
SELECT t.name AS TableName, c.name AS ColumnName, c.column_id AS ColumnId,
       c.system_type_id AS TypeId, c.max_length AS MaxLength,
       c.precision AS [Precision], c.scale AS Scale, c.collation_name AS CollationName,
       c.is_nullable AS IsNullable, c.is_identity AS IsIdentity,
       defaults.definition AS DefaultDefinition
INTO [$originalDatabase].dbo.OriginalColumnDefinitions
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
LEFT JOIN sys.default_constraints AS defaults ON defaults.object_id = c.default_object_id
WHERE s.name = N'dbo' AND t.name IN (N'Form', N'Manager', N'Log');
"@
        Invoke-LegacySql 'master' "ALTER DATABASE [$originalDatabase] SET READ_ONLY;"

        if ($scenario -eq 'DuplicatePublished') {
            Invoke-ProductionStartup $database 'blocked' $true
            $rollbackVerification = @"
IF OBJECT_ID(N'dbo.FormLegacy_PreEf', N'U') IS NOT NULL
   OR (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) <> 4
    THROW 53203, N'Blocked upgrade left partial schema changes.', 1;
"@
            $rollbackVerification += Get-OriginalSchemaComparison $originalDatabase $false
            $rollbackVerification += Get-ExactTableComparison $originalDatabase 'Form' 'Form' $originalFormColumns
            $rollbackVerification += Get-ExactTableComparison $originalDatabase 'Manager' 'Manager' $managerColumns
            $rollbackVerification += Get-ExactTableComparison $originalDatabase 'Log' 'Log' $logColumns
            $rollbackVerification += Get-ExactTableComparison $originalDatabase '__EFMigrationsHistory' '__EFMigrationsHistory' $historyColumns
            Invoke-LegacySql $database $rollbackVerification
            Write-Host 'Legacy duplicate-published preflight preserved every original row and column.'
            continue
        }

        # The first upgrade is always the actual Production startup path.
        # Running dotnet ef first would hide startup-only adoption defects.
        Invoke-ProductionStartup $database 'first'
        $canonicalProjection = Get-BinaryProjection $copiedFormColumns
        $verification = @"
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.FormLegacy_PreEf', N'U') IS NULL
    THROW 53204, N'The original integer-key Form archive is missing.', 1;
IF (SELECT COUNT_BIG(*) FROM dbo.Form) <> (SELECT COUNT_BIG(*) FROM [$originalDatabase].dbo.Form)
   OR EXISTS
   (
       SELECT CONVERT(varbinary(max), Id), $canonicalProjection FROM [$originalDatabase].dbo.Form
       EXCEPT SELECT CONVERT(varbinary(max), LegacyId), $canonicalProjection FROM dbo.Form
   )
   OR EXISTS
   (
       SELECT CONVERT(varbinary(max), LegacyId), $canonicalProjection FROM dbo.Form
       EXCEPT SELECT CONVERT(varbinary(max), Id), $canonicalProjection FROM [$originalDatabase].dbo.Form
   )
    THROW 53205, N'Canonical Form lost or changed an original copied field.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Form AS currentForm
    INNER JOIN [$originalDatabase].dbo.Form AS original ON original.Id = currentForm.LegacyId
    WHERE currentForm.Id <> CONVERT(uniqueidentifier,
              N'f0000000-0000-0000-0000-' + RIGHT(REPLICATE(N'0', 12) + CONVERT(nvarchar(12), original.Id), 12))
       OR currentForm.IsActive <> original.Active
       OR currentForm.IsPublished <> CASE WHEN ISNULL(original.Deleted, 0) = 1 THEN 0 ELSE 1 END
)
    THROW 53206, N'Canonical legacy ID/status mapping changed.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Form AS currentForm
    INNER JOIN [$originalDatabase].dbo.Form AS original ON original.Id = currentForm.LegacyId
    WHERE (original.CreatedDate IS NULL OR MONTH(original.CreatedDate) BETWEEN 6 AND 8)
      AND currentForm.SeasonId IS NOT NULL
)
    THROW 53207, N'An undated/summer Form was assigned an invented season.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Form AS currentForm
    INNER JOIN [$originalDatabase].dbo.Form AS original ON original.Id = currentForm.LegacyId
    LEFT JOIN dbo.Seasons AS season ON season.Id = currentForm.SeasonId
    WHERE original.CreatedDate IS NOT NULL AND MONTH(original.CreatedDate) IN (2, 10, 11)
      AND (season.Id IS NULL OR season.IsPublished <> 1
           OR CONVERT(date, original.CreatedDate) < season.SeasonStartDate
           OR CONVERT(date, original.CreatedDate) > season.SeasonEndDate)
)
    THROW 53208, N'A dated legacy Form was not mapped to its appropriate season.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Form AS formRecord
    LEFT JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    WHERE formRecord.IsPublished = 1 AND formRecord.IsActive = 1
      AND
      (
          (SELECT COUNT(*) FROM dbo.Plays AS linked WHERE linked.SourceFormId = formRecord.Id) <> 1
          OR play.Id IS NULL
          OR play.PlayName IS NULL OR play.TheaterName IS NULL
          OR CONVERT(varbinary(max), play.PlayName) <> CONVERT(varbinary(max), formRecord.RepertoireName)
          OR CONVERT(varbinary(max), play.TheaterName) <> CONVERT(varbinary(max), formRecord.TheatreName)
      )
)
    THROW 53211, N'An active legacy Form did not project its complete names to one linked Play.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    WHERE formRecord.IsPublished = 1 AND formRecord.IsActive = 1
      AND
      (
          (SELECT COUNT(*) FROM dbo.PlayAwardCategories AS candidate
           WHERE candidate.PlayId = play.Id AND candidate.AwardCategoryCode = 1001
             AND candidate.IsCurrent = 1 AND candidate.IsPublished = 1 AND candidate.IsActive = 1) <> 1
          OR NOT EXISTS
          (
              SELECT 1 FROM dbo.PlayAwardCategories AS candidate
              WHERE candidate.PlayId = play.Id AND candidate.AwardCategoryCode = 1001
                AND candidate.IsCurrent = 1 AND candidate.IsPublished = 1 AND candidate.IsActive = 1
                AND CONVERT(varbinary(max), candidate.Candidate) = CONVERT(varbinary(max), formRecord.TheatreName)
          )
      )
)
    THROW 53212, N'A legacy theatre name was changed or truncated in category 1001.', 1;
IF
(
    SELECT COUNT(*) FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.PlayId = play.Id
    WHERE formRecord.LegacyId = 7 AND candidate.AwardCategoryCode = 1006
      AND candidate.IsCurrent = 1 AND candidate.IsPublished = 1 AND candidate.IsActive = 1
) <> 1
OR NOT EXISTS
(
    SELECT 1 FROM dbo.Form AS formRecord
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.PlayId = play.Id
    WHERE formRecord.LegacyId = 7 AND candidate.AwardCategoryCode = 1006
      AND candidate.IsCurrent = 1 AND candidate.IsPublished = 1 AND candidate.IsActive = 1
      AND candidate.SourceFormCandidateOrder = 4
      AND CONVERT(varbinary(max), candidate.Candidate) = CONVERT(varbinary(max), N'Ad')
)
    THROW 53213, N'Mixed legacy JSON did not import only its object candidate at the original array position.', 1;
DECLARE @ExpectedPhotos TABLE
(
    CategoryCode int, SourceOrder int, ContentType nvarchar(100),
    Extension nvarchar(5), ImageData varbinary(max), FileName nvarchar(255) NULL,
    PRIMARY KEY (CategoryCode, SourceOrder)
);
INSERT @ExpectedPhotos (CategoryCode, SourceOrder, ContentType, Extension, ImageData, FileName)
VALUES
    (1003, 1, N'image/png', N'.png', 0x89504E470D0A1A0A, NULL),
    (1003, 2, N'image/jpeg', N'.jpg', 0xFFD8FF, NULL),
    (1003, 3, N'image/webp', N'.webp', 0x524946460000000057454250, NULL),
    (1005, 1, N'image/jpeg', N'.jpg', 0xFFD8FFE000104A4649460001010000D800D80000, N'IMG_1023.jpg');
IF EXISTS
(
    SELECT 1 FROM @ExpectedPhotos AS expected
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.PlayId = play.Id
        INNER JOIN dbo.Images AS image ON image.Id = candidate.PhotoImageId
        WHERE formRecord.LegacyId = 7 AND candidate.AwardCategoryCode = expected.CategoryCode
          AND candidate.SourceFormCandidateOrder = expected.SourceOrder
          AND candidate.IsCurrent = 1 AND candidate.IsPublished = 1 AND candidate.IsActive = 1
          AND image.IsPublished = 1 AND image.ContentType = expected.ContentType
          AND image.ImageData = expected.ImageData
          AND DATALENGTH(image.ImageData) = DATALENGTH(expected.ImageData)
          AND image.FileName = COALESCE(expected.FileName, CONCAT(N'form-candidate-',
              CONVERT(nvarchar(36), candidate.Id), expected.Extension))
    )
)
    THROW 53214, N'Legacy photo bytes, MIME, generated filename or candidate association changed.', 1;
DECLARE @ExpectedMigrations TABLE (MigrationId nvarchar(150) PRIMARY KEY);
INSERT @ExpectedMigrations (MigrationId) VALUES
$expectedMigrationValues;
IF EXISTS (SELECT MigrationId FROM @ExpectedMigrations EXCEPT SELECT MigrationId FROM dbo.__EFMigrationsHistory)
   OR EXISTS (SELECT MigrationId FROM dbo.__EFMigrationsHistory EXCEPT SELECT MigrationId FROM @ExpectedMigrations)
    THROW 53209, N'Legacy production migration history does not match this build.', 1;
"@
        $verification += Get-OriginalSchemaComparison $originalDatabase $true
        $verification += Get-ExactTableComparison $originalDatabase 'Form' 'FormLegacy_PreEf' $originalFormColumns
        $verification += Get-ExactTableComparison $originalDatabase 'Manager' 'Manager' $managerColumns
        $verification += Get-ExactTableComparison $originalDatabase 'Log' 'Log' $logColumns
        Invoke-LegacySql $database $verification

        # Capture the complete upgraded Form (including generated GUID season
        # assignments) and history so a second boot cannot silently duplicate or mutate data.
        Invoke-LegacySql 'master' "ALTER DATABASE [$originalDatabase] SET READ_WRITE;"
        Invoke-LegacySql $database @"
SELECT * INTO [$originalDatabase].dbo.FormAfterFirstStartup FROM dbo.Form;
SELECT * INTO [$originalDatabase].dbo.HistoryAfterFirstStartup FROM dbo.__EFMigrationsHistory;
"@
        Invoke-LegacySql 'master' "ALTER DATABASE [$originalDatabase] SET READ_ONLY;"
        Invoke-ProductionStartup $database 'second'
        Invoke-LegacySql $database $verification
        $currentFormColumns = @('Id', 'LegacyId', 'SeasonId', 'IsActive', 'IsPublished', 'YoungGenerationArtist') + $copiedFormColumns
        $idempotence = Get-ExactTableComparison $originalDatabase 'FormAfterFirstStartup' 'Form' $currentFormColumns
        $idempotence += Get-ExactTableComparison $originalDatabase 'HistoryAfterFirstStartup' '__EFMigrationsHistory' $historyColumns
        Invoke-LegacySql $database $idempotence
        # Seed one historical reference outside strict upload validation, then
        # prove retirement preserves it while new/changed image content stays strict.
        Invoke-LegacySql $database @"
DECLARE @LegacyImageId uniqueidentifier = NEWID();
DISABLE TRIGGER dbo.TR_Images_EnforceMaximumSize ON dbo.Images;
BEGIN TRY
    INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    VALUES (@LegacyImageId, N'eski-referans', N'application/x-afife-legacy-reference',
            0x, SYSDATETIME(), NEWID(), 1);
END TRY
BEGIN CATCH
    ENABLE TRIGGER dbo.TR_Images_EnforceMaximumSize ON dbo.Images;
    THROW;
END CATCH;
ENABLE TRIGGER dbo.TR_Images_EnforceMaximumSize ON dbo.Images;

UPDATE dbo.Images SET IsPublished = 0, UpdatedAt = SYSDATETIME()
WHERE Id = @LegacyImageId;
IF NOT EXISTS
(
    SELECT 1 FROM dbo.Images WHERE Id = @LegacyImageId AND IsPublished = 0
      AND FileName = N'eski-referans'
      AND ContentType = N'application/x-afife-legacy-reference'
      AND DATALENGTH(ImageData) = 0
)
    THROW 53215, N'Metadata-only legacy image retirement changed its original content.', 1;

DECLARE @RejectedInsert bit = 0;
BEGIN TRY
    INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    VALUES (NEWID(), N'invalid.png', N'image/png', 0x3C7363726970743E, SYSDATETIME(), NEWID(), 1);
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52432 SET @RejectedInsert = 1;
    ELSE THROW;
END CATCH;
IF @RejectedInsert = 0
    THROW 53216, N'Invalid new image content bypassed strict upload validation.', 1;

DECLARE @RejectedUpdate bit = 0;
BEGIN TRY
    UPDATE dbo.Images
    SET FileName = N'invalid.png', ContentType = N'image/png', ImageData = 0x3C7363726970743E
    WHERE Id = @LegacyImageId;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 52432 SET @RejectedUpdate = 1;
    ELSE THROW;
END CATCH;
IF @RejectedUpdate = 0
    THROW 53217, N'Invalid changed image content bypassed strict upload validation.', 1;
IF NOT EXISTS
(
    SELECT 1 FROM dbo.Images WHERE Id = @LegacyImageId AND IsPublished = 0
      AND FileName = N'eski-referans'
      AND ContentType = N'application/x-afife-legacy-reference'
      AND DATALENGTH(ImageData) = 0
)
    THROW 53218, N'Rejected image content update damaged the original legacy image.', 1;
"@
        Write-Host "Legacy production Form startup upgrade and repeat startup passed ($scenario)."
    }
}
finally {
    if ($null -ne $application -and -not $application.HasExited) {
        Stop-Process -Id $application.Id -Force -ErrorAction SilentlyContinue
        $application.WaitForExit()
    }
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name]) }
    foreach ($path in $logPaths) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    foreach ($database in $createdDatabases) {
        Assert-DisposableDatabaseName $database
        sqlcmd -I -S $Server -d master -b -Q `
            "IF DB_ID(N'$database') IS NOT NULL BEGIN ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$database]; END;"
    }
    Pop-Location
}
