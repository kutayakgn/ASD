# No build and no database connection: tests package generation/rollback inference.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'migration-sql.ps1')
$script:afifeSqlAssertions = 0
function Assert-AfifeSql([bool] $Condition, [string] $Message) {
    $script:afifeSqlAssertions++
    if (-not $Condition) { throw $Message }
}
function Assert-AfifeSqlRejected([scriptblock] $Operation, [string] $Message) {
    $rejected = $false
    try { & $Operation | Out-Null }
    catch { $rejected = $true }
    Assert-AfifeSql $rejected $Message
}

$afifeSqlTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$afifeSqlTestName = 'AfifeMigrationSqlTests_' + [Guid]::NewGuid().ToString('N')
$afifeSqlTestRoot = [IO.Path]::GetFullPath((Join-Path $afifeSqlTempRoot $afifeSqlTestName))
if (-not $afifeSqlTestRoot.StartsWith($afifeSqlTempRoot, [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $afifeSqlTestRoot) -cnotmatch '^AfifeMigrationSqlTests_[a-f0-9]{32}$') {
    throw 'Disposable SQL fixture path is invalid.'
}
New-Item -ItemType Directory -Path $afifeSqlTestRoot | Out-Null
try {
    $objectRoot = Join-Path $afifeSqlTestRoot 'DatabaseObjects'
    $versionRoot = Join-Path $afifeSqlTestRoot 'Versions'
    foreach ($folder in @('10-Functions', '20-StoredProcedures', '30-Triggers', '50-ReferenceData', '00-Prerequisites', '40-Audit')) {
        New-Item -ItemType Directory -Path (Join-Path $objectRoot $folder) -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $versionRoot | Out-Null
    $fixtures = @{
        '10-Functions/NewFunctionA.sql' = 'CREATE OR ALTER FUNCTION [dbo].[NewFunctionA](@v int) RETURNS int AS BEGIN RETURN @v; END;'
        '10-Functions/NewFunctionB.sql' = 'CREATE OR ALTER FUNCTION dbo.NewFunctionB(@v int) RETURNS int AS BEGIN RETURN dbo.NewFunctionA(@v); END;'
        '20-StoredProcedures/NewProcedure.sql' = "SET ANSI_NULLS ON;`r`nGO`r`nCREATE OR ALTER PROC dbo.NewProcedure AS BEGIN SELECT dbo.NewFunctionB(1); END;"
        '30-Triggers/NewTrigger.sql' = "/* outer /* nested */ comment */`r`nCREATE OR ALTER TRIGGER dbo.NewTrigger ON dbo.Example AFTER UPDATE AS BEGIN DECLARE @s nvarchar(max) = N'CREATE OR ALTER TRIGGER dbo.Quoted AS SELECT ''value'''; SELECT 1; END;"
        '50-ReferenceData/NewSeed.sql' = 'INSERT INTO dbo.Example (Id) SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM dbo.Example WHERE Id = 1);'
        '00-Prerequisites/NewColumn.sql' = 'IF COL_LENGTH(N''dbo.Example'', N''Note'') IS NULL ALTER TABLE dbo.Example ADD Note nvarchar(50) NULL;'
        '30-Triggers/Multiple.sql' = "CREATE OR ALTER TRIGGER dbo.First ON dbo.Example AFTER UPDATE AS SELECT 1;`r`nGO`r`nCREATE OR ALTER TRIGGER dbo.Second ON dbo.Example AFTER UPDATE AS SELECT 1;"
        '30-Triggers/OtherSchema.sql' = 'CREATE OR ALTER TRIGGER other.NewTrigger ON other.Example AFTER UPDATE AS SELECT 1;'
        '30-Triggers/WrongFolder.sql' = 'CREATE OR ALTER PROCEDURE dbo.WrongFolder AS SELECT 1;'
        '30-Triggers/Dynamic.sql' = "EXEC(N'CREATE OR ALTER TRIGGER dbo.Dynamic ON dbo.Example AFTER UPDATE AS SELECT 1;');"
        '20-StoredProcedures/ExtraBatch.sql' = "CREATE OR ALTER PROCEDURE dbo.ExtraBatch AS SELECT 1;`r`nGO`r`nCREATE VIEW dbo.HiddenView AS SELECT 1 AS Id;"
        '20-StoredProcedures/QuotedGo.sql' = "CREATE OR ALTER PROCEDURE dbo.QuotedGo AS BEGIN DECLARE @s nvarchar(max) = N'line`r`nGO`r`nline'; SELECT 1; END;"
        '40-Audit/Unsupported.sql' = 'CREATE OR ALTER VIEW dbo.Unsupported AS SELECT 1 AS Id;'
        '50-ReferenceData/HiddenRoutine.sql' = 'CREATE OR ALTER PROCEDURE dbo.HiddenRoutine AS SELECT 1;'
    }
    foreach ($fixture in $fixtures.GetEnumerator()) {
        Write-AfifeUtf8 (Join-Path $objectRoot $fixture.Key) $fixture.Value
    }
    $newNames = @('10-Functions/NewFunctionA.sql', '10-Functions/NewFunctionB.sql',
        '20-StoredProcedures/NewProcedure.sql', '30-Triggers/NewTrigger.sql',
        '50-ReferenceData/NewSeed.sql', '00-Prerequisites/NewColumn.sql')
    $rollback = Get-AfifeNewModuleRollback $objectRoot $newNames 'SELECT 1;'
    Assert-AfifeSql ($rollback.Count -eq 4) 'Only four new literal routines receive DROP operations.'
    Assert-AfifeSql ($rollback.BeforeSql -ceq 'DROP TRIGGER IF EXISTS [dbo].[NewTrigger];') 'New triggers drop before EF schema rollback.'
    Assert-AfifeSql ($rollback.AfterSql.IndexOf('DROP PROCEDURE') -lt $rollback.AfterSql.IndexOf('DROP FUNCTION')) 'New procedures drop before new functions.'
    Assert-AfifeSql ($rollback.AfterSql.IndexOf('[NewFunctionB]') -lt $rollback.AfterSql.IndexOf('[NewFunctionA]')) 'Functions drop in reverse creation order.'
    Assert-AfifeSql ($rollback.BeforeSql -notmatch 'Quoted' -and $rollback.AfterSql -notmatch 'Quoted') 'Quoted CREATE text does not become a DROP target.'
    Assert-AfifeSql (($rollback.BeforeSql + $rollback.AfterSql) -notmatch 'DELETE|DROP TABLE|DROP COLUMN|NewSeed|NewColumn') 'Seed rows and additive columns remain during rollback.'
    $none = Get-AfifeNewModuleRollback $objectRoot @() 'SELECT 1;'
    Assert-AfifeSql ($none.Count -eq 0 -and $none.BeforeSql -eq '' -and $none.AfterSql -eq '') 'An unchanged module set needs no cleanup.'
    foreach ($invalid in @('30-Triggers/Multiple.sql', '30-Triggers/OtherSchema.sql',
        '30-Triggers/WrongFolder.sql', '30-Triggers/Dynamic.sql', '20-StoredProcedures/ExtraBatch.sql', '20-StoredProcedures/QuotedGo.sql',
        '40-Audit/Unsupported.sql', '50-ReferenceData/HiddenRoutine.sql')) {
        Assert-AfifeSqlRejected { Get-AfifeNewModuleRollback $objectRoot @($invalid) 'SELECT 1;' } "Unsafe/ambiguous definition must fail: $invalid"
    }
    Assert-AfifeSqlRejected {
        Get-AfifeNewModuleRollback $objectRoot @('20-StoredProcedures/NewProcedure.sql') 'CREATE OR ALTER PROCEDURE dbo.NewProcedure AS SELECT 1;'
    } 'A new file cannot overwrite an existing routine under another path.'
    Assert-AfifeSqlRejected { Get-AfifeSqlDefinitionText "SELECT 'unterminated" } 'Unterminated strings are rejected.'
    Assert-AfifeSqlRejected { Get-AfifeSqlDefinitionText '/* unterminated' } 'Unterminated comments are rejected.'
    Assert-AfifeSql (Test-AfifeSqlEquivalent "SELECT 1;`r`nGO`r`n" "SELECT 1;`nGO`n") 'LF and CRLF do not create a false SQL edit.'
    Assert-AfifeSql (-not (Test-AfifeSqlEquivalent 'SELECT 1;' 'SELECT 2;')) 'Actual SQL changes remain significant.'
    Assert-AfifeSql (-not (Test-AfifeSqlEquivalent 'SELECT 1;' 'SELECT  1;')) 'Whitespace other than newline representation remains significant.'
    $twoTriggers = "DROP TRIGGER IF EXISTS [dbo].[First];`r`nDROP TRIGGER IF EXISTS [dbo].[Second];"
    $csharpContent = ConvertTo-AfifeCSharpStringContent $twoTriggers
    Assert-AfifeSql ($csharpContent.Contains('\r\n') -and -not $csharpContent.Contains('\\r\\n')) 'C# newline escapes contain one slash, not literal doubled slashes.'
    Assert-AfifeSql ([regex]::Unescape($csharpContent) -ceq $twoTriggers) 'Generated C# string restores two DROP statements separated by an actual newline.'
    Assert-AfifeSql (('\r'.Length -eq 2) -and ('\\r'.Length -eq 3)) 'PowerShell single-quoted C# escape lengths are explicit.'

    $priorSql = "SELECT 1;`r`nGO`r`n"
    Write-AfifeUtf8 (Join-Path $versionRoot 'Previous_v_20261014.sql') (New-AfifeSqlPackage 'Previous_v_20261014' @{
        UP = @{ Sql = $priorSql; Reference = $null }; DOWN = @{ Sql = $priorSql; Reference = $null }
    } @('50-ReferenceData/Previous.sql'))
    $downSql = $priorSql + [Environment]::NewLine + 'GO' + [Environment]::NewLine + $rollback.AfterSql
    Write-AfifeUtf8 (Join-Path $versionRoot 'Current_v_20261014.sql') (New-AfifeSqlPackage 'Current_v_20261014' @{
        UP = @{ Sql = $priorSql; Reference = 'Previous_v_20261014:UP' }; DOWN = @{ Sql = $downSql; Reference = $null }
    } $newNames)
    Assert-AfifeSql ((Read-AfifeSqlSection $versionRoot 'Current_v_20261014' 'UP') -ceq $priorSql) 'Referenced Up preserves the target exact text/hash.'
    Assert-AfifeSql ((Read-AfifeSqlSection $versionRoot 'Current_v_20261014' 'DOWN') -ceq $downSql) 'Inline Down retains prior definitions plus new routine cleanup.'
    Assert-AfifeSql ((Read-AfifeModuleManifest (Join-Path $versionRoot 'Current_v_20261014.sql')).Count -eq $newNames.Count) 'Added canonical files are captured by the module manifest.'
    $badPackage = New-AfifeSqlPackage 'Broken_v_20261014' @{
        UP = @{ Sql = $priorSql; Reference = 'Broken_v_20261014:UP' }; DOWN = @{ Sql = $priorSql; Reference = $null }
    }
    Write-AfifeUtf8 (Join-Path $versionRoot 'Broken_v_20261014.sql') $badPackage
    Assert-AfifeSqlRejected { Read-AfifeSqlSection $versionRoot 'Broken_v_20261014' 'UP' } 'Circular SQL references are rejected.'
    $badPackage = New-AfifeSqlPackage 'Broken_v_20261014' @{
        UP = @{ Sql = $priorSql; Reference = $null }; DOWN = @{ Sql = $priorSql; Reference = $null }
    }
    Write-AfifeUtf8 (Join-Path $versionRoot 'Broken_v_20261014.sql') ($badPackage.Replace('SELECT 1;', 'SELECT 9;'))
    Assert-AfifeSqlRejected { Read-AfifeSqlSection $versionRoot 'Broken_v_20261014' 'UP' } 'Unexpected payload edits are rejected by the hash.'
    Write-Output "PASS: $script:afifeSqlAssertions SQL package and new-module rollback checks (no DB)."
}
finally {
    # Only this runner's validated GUID-suffixed fixture directory is removed.
    if ((Split-Path -Leaf $afifeSqlTestRoot) -cmatch '^AfifeMigrationSqlTests_[a-f0-9]{32}$' -and
        $afifeSqlTestRoot.StartsWith($afifeSqlTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $afifeSqlTestRoot -Recurse -Force
    }
}
