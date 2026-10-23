param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $PSScriptRoot 'validate-migrations.ps1'
$emptyDatabaseScript = Join-Path $PSScriptRoot 'test-empty-database-migration.ps1'
$oldestPreprodScript = Join-Path $PSScriptRoot 'test-oldest-preprod-migration.ps1'
$legacyFormScript = Join-Path $PSScriptRoot 'test-legacy-form-migration.ps1'
$currentSchemaScript = Join-Path $PSScriptRoot 'test-current-schema-adoption.ps1'
$companyUpgradeScript = Join-Path $PSScriptRoot 'test-company-migration-upgrade.ps1'
$candidateRulesScript = Join-Path $PSScriptRoot 'test-candidate-category-rules.ps1'
$additionalVotingRulesScript = Join-Path $PSScriptRoot 'test-additional-voting-rules.ps1'
$juryHomePageSettingsScript = Join-Path $PSScriptRoot 'test-jury-homepage-settings.ps1'
$dataRetentionScript = Join-Path $PSScriptRoot 'test-data-retention.ps1'
$scopedFormSyncScript = Join-Path $PSScriptRoot 'test-scoped-form-sync.ps1'
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$publishPath = Join-Path $env:TEMP ('YKBAfifeMigrationDeploy_' + [Guid]::NewGuid().ToString('N'))

Push-Location $repositoryRoot
try {
    & (Join-Path $PSScriptRoot 'test-migration-sql-packages.ps1')

    & $validationScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Static migration validation failed.' }

    $modelParityProject = Join-Path $PSScriptRoot 'EntityModelParity.Tests/EntityModelParity.Tests.csproj'
    dotnet build $modelParityProject --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Entity model parity build failed.' }
    dotnet (Join-Path $PSScriptRoot "EntityModelParity.Tests/bin/$Configuration/net8.0/EntityModelParity.Tests.dll")
    if ($LASTEXITCODE -ne 0) { throw 'Entity model parity checks failed.' }

    & $emptyDatabaseScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Empty database migration scenario failed.' }

    & $oldestPreprodScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Oldest-preprod migration scenario failed.' }

    & $legacyFormScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Legacy production Form migration scenario failed.' }

    & $currentSchemaScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Current 27.08 schema adoption scenario failed.' }

    & $companyUpgradeScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Current company migration scenario failed.' }

    & $candidateRulesScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Candidate category rules regression scenario failed.' }

    & $additionalVotingRulesScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Additional voting rules regression scenario failed.' }

    & $juryHomePageSettingsScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Jury home-page settings regression scenario failed.' }

    & $dataRetentionScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Migration data retention scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-credential-compatibility.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Credential compatibility regression scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-shared-admin-data-protection.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Shared admin Data Protection regression scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-admin-workflows.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Admin HTTP workflow regression scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-bulk-vote-reset.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Bulk vote reset regression scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-idle-session.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Idle-session policy/browser regression scenario failed.' }

    foreach ($browserTest in @('test-edit-password.js', 'test-voting-history.js')) {
        node (Join-Path $PSScriptRoot $browserTest)
        if ($LASTEXITCODE -ne 0) { throw "Browser regression failed: $browserTest" }
    }

    & (Join-Path $PSScriptRoot 'test-deployment-preservation.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Deployment data preservation regression scenario failed.' }

    & $scopedFormSyncScript -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Scoped Form synchronization regression scenario failed.' }

    & (Join-Path $PSScriptRoot 'test-db-workload-scope.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Scoped database workload regression scenario failed.' }

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
        $resolvedPublishPath = [IO.Path]::GetFullPath($publishPath)
        $resolvedTempPath = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\', '/')
        if ([IO.Path]::GetDirectoryName($resolvedPublishPath) -eq $resolvedTempPath -and
            [IO.Path]::GetFileName($resolvedPublishPath) -match '^YKBAfifeMigrationDeploy_[a-f0-9]{32}$') {
            Remove-Item -LiteralPath $resolvedPublishPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning 'Publish output cleanup skipped: the path is outside the validated temporary test directory.'
        }
    }
    Pop-Location
}
