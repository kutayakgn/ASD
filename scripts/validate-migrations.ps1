param(
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repositoryRoot "src/YKBAfife"
$projectFile = Join-Path $projectRoot "YKBAfife.csproj"
Push-Location $repositoryRoot
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet tool restore failed." }

    $migrationFiles = Get-ChildItem (Join-Path $projectRoot "Data/Migrations") -Filter "*.cs" | Where-Object { $_.Name -match "^\d+_.+\.cs$" -and $_.Name -notmatch "\.Designer\.cs$" }
    $codeHits = $migrationFiles | Select-String -Pattern "\.(DropTable|DropColumn|DeleteData)\s*\("
    if ($codeHits) { throw "Destructive migration APIs are forbidden: $($codeHits -join [Environment]::NewLine)" }

    $sqlFiles = Get-ChildItem (Join-Path $projectRoot "Migrations/Scripts") -Filter "*.sql"
    $sqlHits = $sqlFiles | Select-String -Pattern "(?i)\b(DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b"
    if ($sqlHits) { throw "Physical data-loss SQL is forbidden: $($sqlHits -join [Environment]::NewLine)" }

    $programmabilityPrerequisites = Join-Path $projectRoot "Migrations/Scripts/ProgrammabilityPrerequisites.sql"
    if (-not (Test-Path $programmabilityPrerequisites)) {
        throw "ProgrammabilityPrerequisites.sql is required before compiling procedures and triggers."
    }
    $migrationResourceHelper = Get-Content (Join-Path $projectRoot "Data/Migrations/MigrationSqlResources.cs") -Raw
    if ($migrationResourceHelper -notmatch 'ProgrammabilityPrerequisites\.sql') {
        throw "MigrationSqlResources must execute ProgrammabilityPrerequisites.sql before Programmability.sql."
    }

    dotnet build $projectFile -c $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Build failed." }

    dotnet tool run dotnet-ef migrations has-pending-model-changes --project $projectFile --startup-project $projectFile --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw "The EF model and migration snapshot differ." }

    $artifactDir = Join-Path $repositoryRoot "artifacts/migrations"
    New-Item -ItemType Directory -Force $artifactDir | Out-Null
    dotnet tool run dotnet-ef migrations script --idempotent --project $projectFile --startup-project $projectFile --configuration $Configuration --no-build --output (Join-Path $artifactDir "YKBAfife-idempotent.sql")
    if ($LASTEXITCODE -ne 0) { throw "Idempotent migration script generation failed." }

    Write-Host "Migration validation completed successfully."
}
finally {
    Pop-Location
}
