param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot 'IdleSession.Tests/IdleSession.Tests.csproj'
Push-Location $repositoryRoot
try {
    dotnet build $project --configuration $Configuration -p:UseAppHost=false
    if ($LASTEXITCODE -ne 0) { throw 'Idle-session policy regression build failed.' }
    dotnet (Join-Path $PSScriptRoot "IdleSession.Tests/bin/$Configuration/net8.0/IdleSession.Tests.dll")
    if ($LASTEXITCODE -ne 0) { throw 'Idle-session policy regression checks failed.' }
    node (Join-Path $PSScriptRoot 'test-idle-session.js')
    if ($LASTEXITCODE -ne 0) { throw 'Idle-session browser regression checks failed.' }
}
finally { Pop-Location }
