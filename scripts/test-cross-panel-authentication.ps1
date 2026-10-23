param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'CrossPanelAuthentication.Tests/CrossPanelAuthentication.Tests.csproj'
$databaseName = 'YkbAfifeCrossPanelTest_' + [Guid]::NewGuid().ToString('N')
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
    $databaseName -notmatch '^YkbAfifeCrossPanelTest_[a-f0-9]{32}$') {
    throw 'Only a validated disposable LocalDB database is allowed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53460, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Cross-panel database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Cross-panel authentication regression build failed.' }
    dotnet (Join-Path $PSScriptRoot "CrossPanelAuthentication.Tests/bin/$Configuration/net8.0/CrossPanelAuthentication.Tests.dll") --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Cross-panel authentication regression failed.' }
}
finally {
    if ($databaseCreated) {
        if ($databaseName -notmatch '^YkbAfifeCrossPanelTest_[a-f0-9]{32}$' -or
            $server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
            throw 'Refusing cleanup outside the validated disposable LocalDB database.'
        }
        sqlcmd -I -S $server -d master -b -l 30 -t 180 -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Cross-panel database cleanup failed: $databaseName" }
    }
    Pop-Location
}
