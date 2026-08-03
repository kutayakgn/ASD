param(
    [Parameter(Mandatory)] [string] $MigrationScript,
    [int] $MaximumBackupAgeHours = 24
)

$ErrorActionPreference = "Stop"
$required = @("AFIFE_SQL_SERVER", "AFIFE_SQL_DATABASE", "AFIFE_BACKUP_CONFIRMED")
foreach ($name in $required) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "Required secured deployment variable '$name' is missing."
    }
}
if ($env:AFIFE_BACKUP_CONFIRMED -ne "YES") {
    throw "AFIFE_BACKUP_CONFIRMED must be exactly YES after a verified restore test."
}
if (-not (Test-Path -LiteralPath $MigrationScript)) {
    throw "Migration artifact was not found: $MigrationScript"
}
if ($env:AFIFE_SQL_SERVER -match "localdb" -or $env:AFIFE_SQL_DATABASE -match "(?i)(local|test|dev)$") {
    Write-Warning "Target naming looks non-production. Confirm the secured deployment variables."
}

$sqlcmd = Get-Command sqlcmd -ErrorAction Stop
$common = @("-S", $env:AFIFE_SQL_SERVER, "-d", $env:AFIFE_SQL_DATABASE, "-b", "-X", "-r", "1")
if (-not [string]::IsNullOrWhiteSpace($env:AFIFE_SQL_USER)) {
    if ([string]::IsNullOrWhiteSpace($env:AFIFE_SQL_PASSWORD)) { throw "AFIFE_SQL_PASSWORD is missing." }
    $env:SQLCMDPASSWORD = $env:AFIFE_SQL_PASSWORD
    $common += @("-U", $env:AFIFE_SQL_USER)
} else {
    $common += "-E"
}

$backupCheck = @"
SET NOCOUNT ON;
IF NOT EXISTS
(
    SELECT 1
    FROM msdb.dbo.backupset
    WHERE database_name = DB_NAME()
      AND type = 'D'
      AND is_copy_only IN (0, 1)
      AND backup_finish_date >= DATEADD(hour, -$MaximumBackupAgeHours, GETDATE())
)
    THROW 51100, 'No recent full database backup is visible in msdb.', 1;
SELECT DB_NAME() DatabaseName, MAX(backup_finish_date) LatestFullBackup
FROM msdb.dbo.backupset WHERE database_name = DB_NAME() AND type = 'D';
"@
& $sqlcmd.Source @common -Q $backupCheck
if ($LASTEXITCODE -ne 0) { throw "Production backup preflight failed." }

$before = Join-Path (Split-Path -Parent $MigrationScript) "pre-migration-row-counts.txt"
& $sqlcmd.Source @common -Q "SET NOCOUNT ON; SELECT s.name+'.'+t.name TableName, SUM(p.rows) [RowCount] FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1) GROUP BY s.name,t.name ORDER BY s.name,t.name;" -o $before
if ($LASTEXITCODE -ne 0) { throw "Pre-migration inventory failed." }

& $sqlcmd.Source @common -i (Resolve-Path $MigrationScript).Path
if ($LASTEXITCODE -ne 0) { throw "EF migration artifact failed. The migration transaction was rolled back." }

$after = Join-Path (Split-Path -Parent $MigrationScript) "post-migration-row-counts.txt"
& $sqlcmd.Source @common -Q "SET NOCOUNT ON; SELECT s.name+'.'+t.name TableName, SUM(p.rows) [RowCount] FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1) GROUP BY s.name,t.name ORDER BY s.name,t.name; SELECT MigrationId,ProductVersion FROM dbo.__EFMigrationsHistory ORDER BY MigrationId;" -o $after
if ($LASTEXITCODE -ne 0) { throw "Post-migration inventory failed." }

Write-Host "Database upgrade completed. Review $before and $after before application rollout."
