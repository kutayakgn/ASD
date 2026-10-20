param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('add', 'remove', 'update', 'list', 'script', 'validate')]
    [string] $Action,

    [Parameter(Position = 1)]
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string] $Name,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationRoot = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'
$objectRoot = Join-Path $repositoryRoot 'src/YKBAfife/Migrations/DatabaseObjects'
$versionRoot = Join-Path $repositoryRoot 'src/YKBAfife/Migrations/Versions'
. (Join-Path $PSScriptRoot 'migration-sql.ps1')

function Invoke-Checked([scriptblock] $Command, [string] $FailureMessage) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

function Invoke-Ef([string[]] $Arguments) {
    & dotnet tool run dotnet-ef @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet ef failed: $($Arguments -join ' ')" }
}

function Get-CanonicalDatabaseObjects {
    return Get-AfifeCanonicalSql $objectRoot
}

function Get-CanonicalModuleNames {
    return @(Get-AfifeCanonicalModuleNames $objectRoot)
}

Push-Location $repositoryRoot
try {
    Invoke-Checked { dotnet tool restore } 'dotnet tool restore failed.'

    $common = @(
        '--project', $project,
        '--startup-project', $project,
        '--configuration', $Configuration
    )

    switch ($Action) {
        'add' {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                throw 'Usage: scripts/migration.ps1 add JuryRuleUpdated'
            }
            if ($Name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
                throw 'Migration name must start with a letter and contain only letters, numbers or underscore.'
            }

            $migrationName = '{0}_v_{1}' -f $Name, (Get-Date -Format 'yyyyMMddHHmmss')
            $previousMigration = Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
                Where-Object { $_.Name -match '^\d+_.+\.cs$' -and $_.Name -notmatch '\.Designer\.cs$' } |
                Sort-Object Name -Descending |
                Select-Object -First 1
            if (-not $previousMigration) {
                throw 'The initial EF migration is missing.'
            }
            $previousLogicalName = $previousMigration.BaseName -replace '^\d+_', ''
            $previousVersionFile = Join-Path $versionRoot "$previousLogicalName.sql"
            if (-not (Test-Path -LiteralPath $previousVersionFile -PathType Leaf)) {
                throw 'The previous versioned SQL package is missing.'
            }
            $previousSql = Read-AfifeSqlSection $versionRoot $previousLogicalName 'UP'
            $previousModules = @(Read-AfifeModuleManifest $previousVersionFile)
            $currentModules = @(Get-CanonicalModuleNames)
            $removedModules = @($previousModules | Where-Object { $currentModules -cnotcontains $_ })
            if ($removedModules.Count -gt 0) {
                throw ('Canonical SQL files cannot disappear silently. Restore the file(s) and ' +
                    'review an explicit compatibility migration before removing database behavior: ' +
                    ($removedModules -join ', '))
            }
            $addedModules = @($currentModules | Where-Object { $previousModules -cnotcontains $_ })
            $moduleRollback = Get-AfifeNewModuleRollback $objectRoot $addedModules $previousSql

            Invoke-Checked { dotnet build $project -c $Configuration } 'Build failed.'
            Invoke-Ef (@('migrations', 'add', $migrationName) + $common + @(
                '--output-dir', 'Data/Migrations', '--no-build'))

            $canonicalSql = Get-CanonicalDatabaseObjects
            $upReference = $null
            $upSql = $canonicalSql
            if (Test-AfifeSqlEquivalent $canonicalSql $previousSql) {
                $upReference = "${previousLogicalName}:UP"
                $upSql = $previousSql # Reference hash covers the actual immutable target.
            }
            $downSql = $previousSql
            $downReference = "${previousLogicalName}:UP"
            if (-not [string]::IsNullOrWhiteSpace($moduleRollback.AfterSql)) {
                $downSql += [Environment]::NewLine + 'GO' + [Environment]::NewLine +
                    '-- Remove new procedures/functions after restoring prior definitions.' +
                    [Environment]::NewLine + $moduleRollback.AfterSql + [Environment]::NewLine
                $downReference = $null
            }
            $sections = @{
                UP = @{ Sql = $upSql; Reference = $upReference }
                DOWN = @{ Sql = $downSql; Reference = $downReference }
            }
            $versionFile = Join-Path $versionRoot "$migrationName.sql"
            if (Test-Path -LiteralPath $versionFile) { throw "SQL package already exists: $versionFile" }
            Write-AfifeUtf8 $versionFile (New-AfifeSqlPackage $migrationName $sections $currentModules)
            # Detect corrupt/incomplete packages before touching the migration source.
            [void](Read-AfifeSqlSection $versionRoot $migrationName 'UP')
            [void](Read-AfifeSqlSection $versionRoot $migrationName 'DOWN')

            $migrationFiles = @(Get-ChildItem -LiteralPath $migrationRoot -File `
                -Filter "*_$migrationName.cs" |
                Where-Object { $_.Name -notmatch '\.Designer\.cs$' } |
                Select-Object -First 2)
            if ($migrationFiles.Count -ne 1) {
                throw "Expected one generated migration for $migrationName, found $($migrationFiles.Count)."
            }
            $migrationFile = $migrationFiles[0]

            $source = Get-Content -Raw -Encoding utf8 -LiteralPath $migrationFile.FullName
            $upCall = @"
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "$migrationName", "Up.sql");
"@ + [Environment]::NewLine
            $downCall = @"
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "$migrationName", "Down.sql");
"@ + [Environment]::NewLine
            $downMarker = $source.IndexOf(
                'protected override void Down(MigrationBuilder migrationBuilder)',
                [StringComparison]::Ordinal)
            if ($downMarker -lt 0) { throw 'Generated Down method was not found.' }
            $upClose = $source.LastIndexOf('        }', $downMarker, [StringComparison]::Ordinal)
            if ($upClose -lt 0) { throw 'Generated Up method closing brace was not found.' }
            $source = $source.Insert($upClose, $upCall)

            if (-not [string]::IsNullOrWhiteSpace($moduleRollback.BeforeSql)) {
                # Drop new triggers before EF archives columns/tables they use.
                # Literal ASCII object names were validated by the package helper.
                $escapedDrops = ConvertTo-AfifeCSharpStringContent $moduleRollback.BeforeSql
                $preDownCall = @"
            // Introduced in this version; remove before schema rollback.
            migrationBuilder.Sql("$escapedDrops");
"@ + [Environment]::NewLine
                $downMarker = $source.IndexOf(
                    'protected override void Down(MigrationBuilder migrationBuilder)',
                    [StringComparison]::Ordinal)
                $downOpen = $source.IndexOf('{', $downMarker, [StringComparison]::Ordinal)
                if ($downOpen -lt 0) { throw 'Generated Down method opening brace was not found.' }
                $source = $source.Insert($downOpen + 1, [Environment]::NewLine + $preDownCall)
            }

            $classClose = $source.LastIndexOf('    }', [StringComparison]::Ordinal)
            $downClose = $source.LastIndexOf('        }', $classClose, [StringComparison]::Ordinal)
            if ($downClose -lt 0) { throw 'Generated Down method closing brace was not found.' }
            $source = $source.Insert($downClose, $downCall)
            Write-AfifeUtf8 $migrationFile.FullName $source

            & (Join-Path $PSScriptRoot 'validate-migrations.ps1') -Configuration $Configuration
            if ($LASTEXITCODE -ne 0) { throw 'Migration validation failed.' }
            Write-Host "Created migration $migrationName."
        }
        'remove' {
            $lastMigration = Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.cs' |
                Where-Object { $_.Name -match '^\d+_.+\.cs$' -and $_.Name -notmatch '\.Designer\.cs$' } |
                Sort-Object Name -Descending |
                Select-Object -First 1
            if (-not $lastMigration -or $lastMigration.BaseName -match 'InitialBaseline') {
                throw 'The managed initial baseline cannot be removed.'
            }

            $logicalName = $lastMigration.BaseName -replace '^\d+_', ''
            Invoke-Ef (@('migrations', 'remove') + $common)
            $versionFile = Join-Path $versionRoot "$logicalName.sql"
            if (Test-Path -LiteralPath $versionFile) {
                Remove-Item -LiteralPath $versionFile -Force
            }
            Write-Host "Removed unapplied migration $logicalName."
        }
        'update' {
            if ($Name) {
                Invoke-Ef (@('database', 'update', $Name) + $common)
            }
            else {
                Invoke-Ef (@('database', 'update') + $common)
            }
        }
        'list' {
            Invoke-Ef (@('migrations', 'list') + $common + @('--no-connect'))
        }
        'script' {
            $artifactDirectory = Join-Path $repositoryRoot 'artifacts/migrations'
            New-Item -ItemType Directory -Force $artifactDirectory | Out-Null
            Invoke-Ef (@('migrations', 'script', '--idempotent') + $common + @(
                '--output', (Join-Path $artifactDirectory 'YKBAfife-idempotent.sql')))
        }
        'validate' {
            & (Join-Path $PSScriptRoot 'validate-migrations.ps1') -Configuration $Configuration
            if ($LASTEXITCODE -ne 0) { throw 'Migration validation failed.' }
        }
    }
}
finally {
    Pop-Location
}
