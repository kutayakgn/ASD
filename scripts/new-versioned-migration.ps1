param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
    [string] $Purpose,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/YKBAfife/YKBAfife.csproj'
$migrationName = 'V{0}_{1}' -f ($Version -replace '\.', '_'), $Purpose

Push-Location $repositoryRoot
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'dotnet tool restore failed.' }

    dotnet build $project -c $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

    dotnet tool run dotnet-ef migrations add $migrationName `
        --project $project `
        --startup-project $project `
        --output-dir Data/Migrations `
        --configuration $Configuration `
        --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Migration creation failed.' }

    Write-Host "Created versioned migration $migrationName."
}
finally {
    Pop-Location
}
