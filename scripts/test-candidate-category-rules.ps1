param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'CandidateCategoryRules.Tests/CandidateCategoryRules.Tests.csproj'
$databaseName = 'YkbAfifeCandidateRulesTest_' + ([Guid]::NewGuid().ToString('N'))
$server = '(localdb)\MSSQLLocalDB'

if ($databaseName -notmatch '^YkbAfifeCandidateRulesTest_[a-f0-9]{32}$') {
    throw 'Disposable candidate regression database name validation failed.'
}

$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    sqlcmd -I -S $server -d master -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable candidate regression database creation failed.' }
    $databaseCreated = $true

    dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Candidate category regression build failed.' }
    $testAssembly = Join-Path $PSScriptRoot "CandidateCategoryRules.Tests/bin/$Configuration/net8.0/CandidateCategoryRules.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Candidate category regression checks failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeCandidateRulesTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -Q `
            "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable test database cleanup failed.' }
    }
    Pop-Location
}
