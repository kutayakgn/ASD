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

function Invoke-Checked([scriptblock] $Command, [string] $FailureMessage) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

function Invoke-Ef([string[]] $Arguments) {
    & dotnet tool run dotnet-ef @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet ef failed: $($Arguments -join ' ')" }
}

function Get-CanonicalDatabaseObjects {
    $files = Get-ChildItem -LiteralPath $objectRoot -Recurse -File -Filter '*.sql' |
        Sort-Object FullName
    if (-not $files) { throw 'No canonical database object SQL files were found.' }

    return ($files | ForEach-Object {
        (Get-Content -Raw -LiteralPath $_.FullName).Trim() +
            [Environment]::NewLine + 'GO' + [Environment]::NewLine
    }) -join [Environment]::NewLine
}

function Write-Utf8([string] $Path, [string] $Content) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false))
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
            $previousVersion = Get-Item (Join-Path $versionRoot $previousLogicalName) -ErrorAction SilentlyContinue
            if (-not $previousVersion) {
                throw 'The initial versioned database-object snapshot is missing.'
            }

            Invoke-Checked { dotnet build $project -c $Configuration } 'Build failed.'
            Invoke-Ef (@('migrations', 'add', $migrationName) + $common + @(
                '--output-dir', 'Data/Migrations', '--no-build'))

            $versionDirectory = Join-Path $versionRoot $migrationName
            New-Item -ItemType Directory -Force $versionDirectory | Out-Null
            Write-Utf8 (Join-Path $versionDirectory 'Up.sql') (Get-CanonicalDatabaseObjects)
            Copy-Item -LiteralPath (Join-Path $previousVersion.FullName 'Up.sql') `
                -Destination (Join-Path $versionDirectory 'Down.sql')

            $migrationFiles = @(Get-ChildItem -LiteralPath $migrationRoot -File `
                -Filter "*_$migrationName.cs" |
                Where-Object { $_.Name -notmatch '\.Designer\.cs$' } |
                Select-Object -First 2)
            if ($migrationFiles.Count -ne 1) {
                throw "Expected one generated migration for $migrationName, found $($migrationFiles.Count)."
            }
            $migrationFile = $migrationFiles[0]

            $source = Get-Content -Raw -LiteralPath $migrationFile.FullName
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

            $classClose = $source.LastIndexOf('    }', [StringComparison]::Ordinal)
            $downClose = $source.LastIndexOf('        }', $classClose, [StringComparison]::Ordinal)
            if ($downClose -lt 0) { throw 'Generated Down method closing brace was not found.' }
            $source = $source.Insert($downClose, $downCall)
            Write-Utf8 $migrationFile.FullName $source

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
            $versionDirectory = Join-Path $versionRoot $logicalName
            if (Test-Path $versionDirectory) {
                Remove-Item -LiteralPath $versionDirectory -Recurse -Force
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
