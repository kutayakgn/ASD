param(
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [switch] $NoBuild
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testProject = Join-Path $PSScriptRoot 'JuryBirthDate.Tests/JuryBirthDate.Tests.csproj'
$databaseName = 'YkbAfifeJuryBirthDateTest_' + ([Guid]::NewGuid().ToString('N'))
$server = if ($env:AFIFE_TEST_SQL_SERVER) { $env:AFIFE_TEST_SQL_SERVER } else { '(localdb)\MSSQLLocalDB' }
if ($server -notmatch '^\(localdb\)\\[A-Za-z0-9_-]+$' -or
    $databaseName -notmatch '^YkbAfifeJuryBirthDateTest_[a-f0-9]{32}$') {
    throw 'Only a dedicated GUID-suffixed LocalDB test database is permitted.'
}
$connectionString = "Server=$server;Database=$databaseName;Trusted_Connection=True;TrustServerCertificate=True"
$databaseCreated = $false
Push-Location $repositoryRoot
try {
    if (-not $NoBuild) {
        dotnet build $testProject --configuration $Configuration -p:UseAppHost=false
        if ($LASTEXITCODE -ne 0) { throw 'Jury birthday regression build failed.' }
    }
    sqlcmd -I -S $server -d master -b -l 15 -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) { throw 'Disposable jury birthday database creation failed.' }
    $databaseCreated = $true
    $testAssembly = Join-Path $PSScriptRoot "JuryBirthDate.Tests/bin/$Configuration/net8.0/JuryBirthDate.Tests.dll"
    dotnet $testAssembly --connection $connectionString
    if ($LASTEXITCODE -ne 0) { throw 'Jury birthday regression checks failed.' }
}
finally {
    if ($databaseCreated -and $databaseName -match '^YkbAfifeJuryBirthDateTest_[a-f0-9]{32}$') {
        sqlcmd -I -S $server -d master -b -l 15 -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END;"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Disposable jury birthday test database cleanup failed.' }
    }
    Pop-Location
}
