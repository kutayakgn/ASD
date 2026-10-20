param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'AdditionalVotingRules.Tests/AdditionalVotingRules.Tests.csproj'
$databaseName = 'YkbAfifeAdditionalVotingTest_' + ([Guid]::NewGuid().ToString('N'))
$server = '(localdb)\MSSQLLocalDB'
if ($databaseName -notmatch '^YkbAfifeAdditionalVotingTest_[a-f0-9]{32}$') {
    throw 'Disposable additional voting database name validation failed.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable additional voting database creation failed.' }
    $databaseCreated = $true
    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Additional voting regression build failed.' }
    $testAssembly = Join-Path $PSScriptRoot "AdditionalVotingRules.Tests/bin/$Configuration/net8.0/AdditionalVotingRules.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Additional voting regression checks failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeAdditionalVotingTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable additional voting database cleanup failed.' }
    }
    Pop-Location
}
