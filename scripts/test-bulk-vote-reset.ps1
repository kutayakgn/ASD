param(
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [string] $Server = $(if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' })
)
$ErrorActionPreference = 'Stop'
if ($Server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
    ($env:AFIFE_TEST_SQL_SERVER -and $env:AFIFE_TEST_SQL_SERVER -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$')) {
    throw 'Bulk vote reset tests require a local SQL Server LocalDB instance.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'BulkVoteReset.Tests/BulkVoteReset.Tests.csproj'
$databaseName = 'YkbAfifeBulkVotesTest_' + [Guid]::NewGuid().ToString('N')
$connectionString = "Server=$Server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
function Assert-BulkTestDatabaseName {
    if ($databaseName -notmatch '^YkbAfifeBulkVotesTest_[a-f0-9]{32}$') { throw 'Disposable bulk vote database name validation failed.' }
}
Push-Location $repositoryRoot
try {
    Assert-BulkTestDatabaseName
    sqlcmd -I -S $Server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53390, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable bulk vote database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Bulk vote reset test build failed.' }
    $assembly = Join-Path $PSScriptRoot "BulkVoteReset.Tests/bin/$Configuration/net8.0/BulkVoteReset.Tests.dll"
    dotnet $assembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Bulk vote reset regression checks failed.' }
}
finally {
    if ($databaseCreated) {
        Assert-BulkTestDatabaseName
        sqlcmd -I -S $Server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable bulk vote database cleanup failed: $databaseName" }
    }
    Pop-Location
}
