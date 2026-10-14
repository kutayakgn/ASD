param(
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repositoryRoot 'src/YKBAfife'
$projectFile = Join-Path $projectRoot 'YKBAfife.csproj'
$migrationRoot = Join-Path $projectRoot 'Data/Migrations'
$objectRoot = Join-Path $projectRoot 'Migrations/DatabaseObjects'
$versionRoot = Join-Path $projectRoot 'Migrations/Versions'

Push-Location $repositoryRoot
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'dotnet tool restore failed.' }

    $migrations = @(Get-ChildItem -LiteralPath $migrationRoot -Filter '*.cs' |
        Where-Object { $_.Name -match '^\d+_.+\.cs$' -and $_.Name -notmatch '\.Designer\.cs$' } |
        Sort-Object Name)
    if ($migrations.Count -lt 1) { throw 'At least the managed initial baseline is required.' }

    foreach ($migration in $migrations) {
        $logicalName = $migration.BaseName -replace '^\d+_', ''
        if ($logicalName -notmatch '_v_\d{8,14}$') {
            throw "Migration $($migration.Name) must end with _v_<date>."
        }

        $versionDirectory = Join-Path $versionRoot $logicalName
        foreach ($direction in @('Up.sql', 'Down.sql')) {
            if (-not (Test-Path (Join-Path $versionDirectory $direction))) {
                throw "Versioned database-object snapshot missing: $logicalName/$direction"
            }
        }
    }

    $codeHits = $migrations | Select-String -Pattern '\.DeleteData\s*\('
    if ($codeHits) {
        throw "Destructive migration APIs are forbidden: $($codeHits -join [Environment]::NewLine)"
    }

    $canonicalModules = @(Get-ChildItem -LiteralPath $objectRoot -Recurse -File -Filter '*.sql')
    if ($canonicalModules.Count -eq 0) { throw 'Canonical database object files are missing.' }
    $requiredFolders = @(
        '00-Prerequisites', '10-Functions', '20-StoredProcedures',
        '30-Triggers', '40-Audit', '50-ReferenceData'
    )
    foreach ($folder in $requiredFolders) {
        if (-not (Test-Path (Join-Path $objectRoot $folder))) {
            throw "Canonical database object folder is missing: $folder"
        }
    }

    $sqlFiles = @(
        Get-ChildItem (Join-Path $projectRoot 'Migrations/Scripts') -Filter '*.sql'
        Get-ChildItem $objectRoot -Recurse -Filter '*.sql'
        Get-ChildItem $versionRoot -Recurse -Filter '*.sql'
    )
    $sqlHits = $sqlFiles | Select-String -Pattern '(?i)\b(DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b'
    if ($sqlHits) {
        throw "Physical schema/data-loss SQL is forbidden: $($sqlHits -join [Environment]::NewLine)"
    }

    $baseline = $migrations[0]
    $baselineContent = Get-Content -Raw -LiteralPath $baseline.FullName
    if ($baselineContent -notmatch 'ExecuteLegacyBaselineUpgrade' -or
        $baselineContent -notmatch 'AdoptSquashedBaseline' -or
        $baselineContent -notmatch 'ExecuteVersionedDatabaseObjects') {
        throw 'The initial baseline must retain legacy convergence, history adoption and versioned database objects.'
    }

    dotnet build $projectFile -c $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

    dotnet tool run dotnet-ef migrations has-pending-model-changes `
        --project $projectFile `
        --startup-project $projectFile `
        --configuration $Configuration `
        --no-build
    if ($LASTEXITCODE -ne 0) { throw 'The EF model and migration snapshot differ.' }

    $artifactDirectory = Join-Path $repositoryRoot 'artifacts/migrations'
    New-Item -ItemType Directory -Force $artifactDirectory | Out-Null
    dotnet tool run dotnet-ef migrations script --idempotent `
        --project $projectFile `
        --startup-project $projectFile `
        --configuration $Configuration `
        --no-build `
        --output (Join-Path $artifactDirectory 'YKBAfife-idempotent.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Idempotent migration script generation failed.' }

    Write-Host 'Migration validation completed successfully.'
}
finally {
    Pop-Location
}
