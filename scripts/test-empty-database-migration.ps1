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
    WHERE MigrationId LIKE N'%[_]InitialBaseline[_]v[_]20260827'
)
    THROW 53110, N'Latest migration was not recorded on the empty database.', 1;

IF OBJECT_ID(N'dbo.Form', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Plays', N'U') IS NULL
   OR OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Images', N'U') IS NULL
   OR OBJECT_ID(N'dbo.AdminLogs', N'U') IS NULL
   OR OBJECT_ID(N'dbo.JuryPasswordResetTokens', N'U') IS NULL
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

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'CK_Users_Username_InstagramFormat'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
    THROW 53115, N'Username format constraint is missing, disabled or untrusted.', 1;

IF OBJECT_ID(N'dbo.ufn_CreatePlaySlug', N'FN') IS NULL
   OR OBJECT_ID(N'dbo.TR_Plays_SynchronizeSlug', N'TR') IS NULL
    THROW 53116, N'Play slug synchronization objects are missing.', 1;

DECLARE @TurkishPlayName nvarchar(255) =
    NCHAR(199) + NCHAR(305) + N'l' + N'g' + NCHAR(305) + N'n ' +
    NCHAR(350) + NCHAR(246) + N'len!';

DECLARE @ActualSlug varchar(255) = dbo.ufn_CreatePlaySlug(@TurkishPlayName);
IF @ActualSlug <> 'cilgin-solen'
BEGIN
    DECLARE @SlugError nvarchar(2048) =
        N'Play slug normalization returned [' + COALESCE(@ActualSlug, N'<NULL>') + N'].';
    THROW 53117, @SlugError, 1;
END;

BEGIN TRY
    INSERT INTO dbo.Users
    (
        Id, FirstName, LastName, Phone, Username, PasswordHash, Email,
        CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished,
        RoleCode, GroupCode, PhotoImageId, IsActive, IsJuryPresident
    )
    VALUES
    (
        NEWID(), N'Test', N'User', NULL, N'invalid username', N'not-a-real-hash',
        N'username-rule-test@example.invalid', SYSDATETIME(), NULL, NULL, NULL,
        1, 1, NULL, NULL, 1, 0
    );

    THROW 53118, N'Invalid username was accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 53118
        THROW;
    IF ERROR_NUMBER() <> 547
        THROW;
END CATCH;

BEGIN TRANSACTION;
DECLARE @FirstPlayId uniqueidentifier = NEWID();
DECLARE @SecondPlayId uniqueidentifier = NEWID();

INSERT INTO dbo.Plays
(
    Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
    IsPublished, Slug, TheaterName, Phone, ContactPersonName,
    ContactPersonPhone, Address, Email, JuriOylamaStatus, KunyeGirisStatus,
    RecordType, SourceFormId, IsActive
)
VALUES
(@FirstPlayId, N'İlk Oyun', 6, SYSDATETIME(), NULL, NULL, NULL, 1,
 'ilk-oyun', N'Test Tiyatrosu', NULL, NULL, NULL, NULL, NULL, 0, 0, 1, NULL, 1),
(@SecondPlayId, N'İkinci Oyun', 6, SYSDATETIME(), NULL, NULL, NULL, 1,
 'ikinci-oyun', N'Test Tiyatrosu', NULL, NULL, NULL, NULL, NULL, 0, 0, 1, NULL, 1);

UPDATE dbo.Plays SET PlayName = @TurkishPlayName WHERE Id = @FirstPlayId;
UPDATE dbo.Plays SET PlayName = @TurkishPlayName WHERE Id = @SecondPlayId;

IF (SELECT Slug FROM dbo.Plays WHERE Id = @FirstPlayId) <> 'cilgin-solen'
    THROW 53119, N'PlayName update did not synchronize the slug.', 1;

IF (SELECT Slug FROM dbo.Plays WHERE Id = @SecondPlayId) <> 'cilgin-solen-2'
    THROW 53120, N'Colliding play slug did not receive a deterministic suffix.', 1;

ROLLBACK TRANSACTION;
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
