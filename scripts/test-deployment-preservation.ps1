param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'DeploymentPreservation.Tests/DeploymentPreservation.Tests.csproj'
$databaseName = 'YkbAfifeDeploymentPreservationTest_' + [Guid]::NewGuid().ToString('N')
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
    throw 'AFIFE_TEST_SQL_SERVER must name a local SQL Server LocalDB instance.'
}
if ($databaseName -notmatch '^YkbAfifeDeploymentPreservationTest_[a-f0-9]{32}$') {
    throw 'Disposable deployment-preservation database name validation failed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -l 30 -Q "IF DB_ID(N'$databaseName') IS NOT NULL THROW 53450, N'Disposable database already exists.', 1; CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable deployment-preservation database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Deployment-preservation regression build failed.' }
    $testAssembly = Join-Path $PSScriptRoot "DeploymentPreservation.Tests/bin/$Configuration/net8.0/DeploymentPreservation.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Deployment-preservation regression failed.' }
}
finally {
    if ($databaseCreated) {
        if ($databaseName -notmatch '^YkbAfifeDeploymentPreservationTest_[a-f0-9]{32}$' -or
            $server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$') {
            throw 'Refusing cleanup of an unvalidated disposable LocalDB database.'
        }
        sqlcmd -I -S $server -d master -b -l 30 -t 180 -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning "Disposable deployment-preservation cleanup failed: $databaseName" }
    }
    Pop-Location
}
