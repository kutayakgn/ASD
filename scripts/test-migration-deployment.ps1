param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $PSScriptRoot 'validate-migrations.ps1'
$emptyDatabaseScript = Join-Path $PSScriptRoot 'test-empty-database-migration.ps1'
$oldestPreprodScript = Join-Path $PSScriptRoot 'test-oldest-preprod-migration.ps1'
$companyUpgradeScript = Join-Path $PSScriptRoot 'test-company-migration-upgrade.ps1'
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$publishPath = Join-Path $env:TEMP ('YKBAfifeMigrationDeploy_' + [Guid]::NewGuid().ToString('N'))

Push-Location $repositoryRoot
try {
    & $validationScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Static migration validation failed.' }

    & $emptyDatabaseScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Empty database migration scenario failed.' }

    & $oldestPreprodScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Oldest-preprod migration scenario failed.' }

    & $companyUpgradeScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Current company migration scenario failed.' }

    dotnet publish $project --no-restore -c $Configuration -o $publishPath
    if ($LASTEXITCODE -ne 0) { throw 'Deployment publish validation failed.' }
    if (-not (Test-Path (Join-Path $publishPath 'YKBAfife.dll'))) {
        throw 'Published application DLL is missing.'
    }
    if (-not (Test-Path (Join-Path $publishPath 'web.config'))) {
        throw 'Published web.config is missing.'
    }

    Write-Host 'All migration deployment scenarios completed successfully.'
}
finally {
    if (Test-Path $publishPath) {
        Remove-Item -LiteralPath $publishPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}
