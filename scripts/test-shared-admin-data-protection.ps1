param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$databaseName = 'YkbAfifeSharedAdminKeysTest_' + [Guid]::NewGuid().ToString('N')
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
    $databaseName -notmatch '^YkbAfifeSharedAdminKeysTest_[a-f0-9]{32}$') {
    throw 'Only a GUID-suffixed disposable LocalDB key-sharing test is allowed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$created = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53460, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable key-sharing database creation failed.' }
    $created = $true
    $project = Join-Path $PSScriptRoot 'SharedAdminDataProtection.Tests/SharedAdminDataProtection.Tests.csproj'
    dotnet build $project --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Shared admin Data Protection regression build failed.' }
    dotnet (Join-Path $PSScriptRoot "SharedAdminDataProtection.Tests/bin/$Configuration/net8.0/SharedAdminDataProtection.Tests.dll") --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Shared admin Data Protection regression failed.' }
}
finally {
    if ($created) {
        if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
            $databaseName -notmatch '^YkbAfifeSharedAdminKeysTest_[a-f0-9]{32}$') {
            throw 'Refusing cleanup outside the dedicated LocalDB key-sharing database.'
        }
        sqlcmd -I -S $server -d master -b -l 30 -t 180 -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable key-sharing cleanup failed: $databaseName" }
    }
    Pop-Location
}
