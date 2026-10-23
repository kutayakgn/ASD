param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'CredentialCompatibility.Tests/CredentialCompatibility.Tests.csproj'
dotnet build $project --configuration $Configuration -p:UseAppHost=false
if ($LASTEXITCODE -ne 0) { throw 'Credential compatibility test build failed.' }
dotnet (Join-Path $PSScriptRoot "CredentialCompatibility.Tests/bin/$Configuration/net8.0/CredentialCompatibility.Tests.dll")
if ($LASTEXITCODE -ne 0) { throw 'Credential compatibility regression failed.' }
