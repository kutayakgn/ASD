param(
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet tool restore failed." }

    $migrationFiles = Get-ChildItem "Data/Migrations" -Filter "*.cs" | Where-Object { $_.Name -match "^\d+_.+\.cs$" -and $_.Name -notmatch "\.Designer\.cs$" }
    $codeHits = $migrationFiles | Select-String -Pattern "\.(DropTable|DropColumn|DeleteData)\s*\("
    if ($codeHits) { throw "Destructive migration APIs are forbidden: $($codeHits -join [Environment]::NewLine)" }

    $sqlFiles = Get-ChildItem "Migrations/Scripts" -Filter "*.sql"
    $sqlHits = $sqlFiles | Select-String -Pattern "(?i)\b(DELETE\s+FROM|TRUNCATE\s+TABLE|DROP\s+TABLE|DROP\s+COLUMN)\b"
    if ($sqlHits) { throw "Physical data-loss SQL is forbidden: $($sqlHits -join [Environment]::NewLine)" }

    dotnet build -c $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Build failed." }

    dotnet tool run dotnet-ef migrations has-pending-model-changes --configuration $Configuration --no-build
    if ($LASTEXITCODE -ne 0) { throw "The EF model and migration snapshot differ." }

    $artifactDir = Join-Path $root "artifacts/migrations"
    New-Item -ItemType Directory -Force $artifactDir | Out-Null
    dotnet tool run dotnet-ef migrations script --idempotent --configuration $Configuration --no-build --output (Join-Path $artifactDir "YKBAfife-idempotent.sql")
    if ($LASTEXITCODE -ne 0) { throw "Idempotent migration script generation failed." }

    Write-Host "Migration validation completed successfully."
}
finally {
    Pop-Location
}
