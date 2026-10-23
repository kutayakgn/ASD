param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.'
}
$databaseName = 'YkbAfifeAdminWorkflowTest_' + [Guid]::NewGuid().ToString('N')
if ($databaseName -notmatch '^YkbAfifeAdminWorkflowTest_[a-f0-9]{32}$') {
    throw 'Disposable admin workflow database validation failed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$testProject = Join-Path $PSScriptRoot 'AdminWorkflow.Tests/AdminWorkflow.Tests.csproj'
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -l 30 -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable admin workflow database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Admin HTTP workflow build failed.' }
    dotnet (Join-Path $PSScriptRoot "AdminWorkflow.Tests/bin/$Configuration/net8.0/AdminWorkflow.Tests.dll") `
        --connection $connectionString --root $repositoryRoot --configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Admin HTTP workflow regression failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeAdminWorkflowTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -l 30 -t 180 -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable admin workflow database cleanup failed.' }
    }
    Pop-Location
}
