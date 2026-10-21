param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'JuryHomePageSettings.Tests/JuryHomePageSettings.Tests.csproj'
$databaseName = 'YkbAfifeHomePageSettingsTest_' + ([Guid]::NewGuid().ToString('N'))
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.'
}
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.'
}
if ($databaseName -notmatch '^YkbAfifeHomePageSettingsTest_[a-f0-9]{32}$') {
    throw 'Disposable jury home page settings database name validation failed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable jury home page settings database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Jury home page settings regression build failed.' }
    $testAssembly = Join-Path $PSScriptRoot "JuryHomePageSettings.Tests/bin/$Configuration/net8.0/JuryHomePageSettings.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Jury home page settings regression checks failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeHomePageSettingsTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable jury home page settings database cleanup failed.' }
    }
    Pop-Location
}
