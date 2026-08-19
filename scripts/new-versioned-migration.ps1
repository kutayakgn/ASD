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
$versionPrefix = 'V{0}_' -f ($Version -replace '\.', '_')
$migrationDirectory = Join-Path $repositoryRoot 'src/YKBAfife/Data/Migrations'

$existingVersion = Get-ChildItem $migrationDirectory -Filter '*.cs' |
    Where-Object {
        $_.Name -notmatch '\.Designer\.cs$' -and
        $_.BaseName -match ('^\d+_' + [Regex]::Escape($versionPrefix))
    } |
    Select-Object -First 1
if ($existingVersion) {
    throw "Version $Version is already used by $($existingVersion.Name). Use the next patch/minor/major version."
}

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

    & (Join-Path $repositoryRoot 'scripts/validate-migrations.ps1') -Configuration $Configuration
    if ($LASTEXITCODE -ne 0) { throw 'Migration validation failed.' }

    Write-Host "Created and validated versioned migration $migrationName."
}
finally {
    Pop-Location
}
