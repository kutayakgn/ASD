param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'DataRetention.Tests/DataRetention.Tests.csproj'
$databaseName = 'YkbAfifeDataRetentionTest_' + ([Guid]::NewGuid().ToString('N'))
$server = '(localdb)\MSSQLLocalDB'
if ($databaseName -notmatch '^YkbAfifeDataRetentionTest_[a-f0-9]{32}$') { throw 'Disposable database name validation failed.' }
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable retention database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Data retention regression build failed.' }
    $testAssembly = Join-Path $PSScriptRoot "DataRetention.Tests/bin/$Configuration/net8.0/DataRetention.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Data retention regression failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeDataRetentionTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable retention database cleanup failed.' }
    }
    Pop-Location
}
