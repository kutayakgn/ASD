# Shared, deliberately text-only SQL package helpers. No database is accessed.
# A version has one readable .sql file; sections may refer to an earlier section.

function Get-AfifeSqlHash([string] $Content) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($Content)))).Replace('-', '')
    }
    finally { $algorithm.Dispose() }
}

function Get-AfifeSqlLfHash([string] $Content) {
    # Only CRLF/LF representation is transport-independent. Do not trim text,
    # remove a payload BOM, or normalize bare CR, whitespace or SQL literals.
    return Get-AfifeSqlHash ($Content.Replace("`r`n", "`n"))
}

function Get-AfifeSqlBatchCount([string] $Content) {
    return @([regex]::Split($Content, '(?im)^\s*GO\s*(?:--.*)?$') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

function Get-AfifeCanonicalSql(
    [string] $ObjectRoot,
    [switch] $ExcludeReferenceData,
    [switch] $OnlyReferenceData
) {
    if ($ExcludeReferenceData -and $OnlyReferenceData) {
        throw 'Select either routine SQL or reference SQL, not both.'
    }
    $files = @(Get-ChildItem -LiteralPath $ObjectRoot -Recurse -File -Filter '*.sql' |
        Where-Object {
            $relative = $_.FullName.Substring($ObjectRoot.Length + 1).Replace('\', '/')
            $isReference = $relative.StartsWith('50-ReferenceData/', [StringComparison]::Ordinal)
            (-not $ExcludeReferenceData -or -not $isReference) -and
                (-not $OnlyReferenceData -or $isReference)
        } |
        Sort-Object FullName)
    if ($files.Count -eq 0) {
        if ($OnlyReferenceData) { return '' }
        throw 'Canonical database SQL modules are missing.'
    }
    return ($files | ForEach-Object {
        [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8).Trim() +
            [Environment]::NewLine + 'GO' + [Environment]::NewLine
    }) -join [Environment]::NewLine
}

function Get-AfifeMigrationSqlComposition(
    [string] $ObjectRoot,
    [string] $VersionRoot,
    [string] $PreviousVersion
) {
    $canonicalSql = Get-AfifeCanonicalSql $ObjectRoot
    $routineSql = Get-AfifeCanonicalSql $ObjectRoot -ExcludeReferenceData
    $referenceSql = Get-AfifeCanonicalSql $ObjectRoot -OnlyReferenceData
    $previousPath = Join-Path $VersionRoot "$PreviousVersion.sql"
    $previousPackage = [IO.File]::ReadAllText($previousPath, [Text.Encoding]::UTF8)
    $previousCanonical = Read-AfifeSqlSection $VersionRoot $PreviousVersion $(
        if ($previousPackage -cmatch '<AFIFE:SHA256:CANONICAL=') { 'CANONICAL' } else { 'UP' })

    if ($previousPackage -cmatch '<AFIFE:SHA256:REFERENCES=') {
        $previousReferences = Read-AfifeSqlSection $VersionRoot $PreviousVersion 'REFERENCES'
    }
    else {
        # The old format stored all canonical files in UP without file boundaries.
        # We can safely identify its seed tail only when those sources are still
        # unchanged. Fail closed rather than guessing old SQL statement boundaries.
        $previousReferences = $referenceSql
    }
    $previousCanonicalLf = $previousCanonical.Replace("`r`n", "`n")
    $previousReferencesLf = $previousReferences.Replace("`r`n", "`n")
    $previousRoutines = $previousCanonicalLf
    if (-not [string]::IsNullOrEmpty($previousReferencesLf)) {
        $referenceTail = "`n" + $previousReferencesLf
        if (-not $previousCanonicalLf.EndsWith($referenceTail, [StringComparison]::Ordinal)) {
            throw ('Cannot safely identify the previous reference-data SQL. ' +
                'Create the first safe-format migration with reference sources unchanged; ' +
                'then capture an intentional reference-data edit in a separate migration.')
        }
        $previousRoutines = $previousCanonicalLf.Substring(0,
            $previousCanonicalLf.Length - $referenceTail.Length)
    }

    $referencesChanged = -not (Test-AfifeSqlEquivalent $referenceSql $previousReferences)
    return [pscustomobject]@{
        CanonicalSql = $canonicalSql
        ReferenceSql = $referenceSql
        UpSql = $(if ($referencesChanged) { $canonicalSql } else { $routineSql })
        DownSql = $previousRoutines
        ReferencesChanged = $referencesChanged
    }
}

function Get-AfifeCanonicalModuleNames([string] $ObjectRoot) {
    return @(Get-ChildItem -LiteralPath $ObjectRoot -Recurse -File -Filter '*.sql' |
        Sort-Object FullName |
        ForEach-Object { $_.FullName.Substring($ObjectRoot.Length + 1).Replace('\', '/') })
}

function Test-AfifeSqlEquivalent([string] $Left, [string] $Right) {
    # Git/source editors may use LF or CRLF. Everything except this newline
    # representation remains significant, including whitespace and SQL literals.
    return $Left.Replace("`r`n", "`n") -ceq $Right.Replace("`r`n", "`n")
}

function ConvertTo-AfifeCSharpStringContent([string] $Value) {
    # PowerShell single-quoted '\r' contains ONE slash followed by r. The
    # generated C# compiler converts that escape back to a real carriage return.
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
}

function Get-AfifeSqlDefinitionText([string] $Sql) {
    # Mask comments and string literals so quoted/dynamic CREATE statements
    # cannot be mistaken for a literal database object definition.
    $characters = $Sql.ToCharArray()
    $state = 'text'
    $blockDepth = 0
    for ($position = 0; $position -lt $characters.Length; $position++) {
        $current = $Sql[$position]
        $next = if ($position + 1 -lt $Sql.Length) { $Sql[$position + 1] } else { [char]0 }
        $lineBreak = $current -eq "`r" -or $current -eq "`n"
        if ($state -eq 'string') {
            if (-not $lineBreak) { $characters[$position] = ' ' }
            if ($current -eq "'") {
                if ($next -eq "'") { $characters[++$position] = ' ' }
                else { $state = 'text' }
            }
        }
        elseif ($state -eq 'line') {
            if ($lineBreak) { $state = 'text' }
            else { $characters[$position] = ' ' }
        }
        elseif ($state -eq 'block') {
            if (-not $lineBreak) { $characters[$position] = ' ' }
            if ($current -eq '/' -and $next -eq '*') {
                $characters[++$position] = ' '; $blockDepth++
            }
            elseif ($current -eq '*' -and $next -eq '/') {
                $characters[++$position] = ' '; $blockDepth--
                if ($blockDepth -eq 0) { $state = 'text' }
            }
        }
        elseif ($current -eq "'") { $characters[$position] = ' '; $state = 'string' }
        elseif ($current -eq '-' -and $next -eq '-') {
            $characters[$position] = ' '; $characters[++$position] = ' '; $state = 'line'
        }
        elseif ($current -eq '/' -and $next -eq '*') {
            $characters[$position] = ' '; $characters[++$position] = ' '; $state = 'block'; $blockDepth = 1
        }
    }
    if ($state -eq 'string' -or $state -eq 'block') {
        throw 'SQL has an unterminated string/comment. Review the file before scaffolding a migration.'
    }
    return -join $characters
}

function Get-AfifeNewModuleRollback(
    [string] $ObjectRoot,
    [string[]] $AddedModuleNames,
    [string] $PreviousSql
) {
    if ($AddedModuleNames.Count -eq 0) {
        return [pscustomobject]@{ BeforeSql = ''; AfterSql = ''; Count = 0 }
    }
    $options = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [Text.RegularExpressions.RegexOptions]::Multiline -bor
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $definitionPattern = '^\s*CREATE\s+OR\s+ALTER\s+(?<kind>PROCEDURE|PROC|FUNCTION|TRIGGER)\s+(?<schema>\[dbo\]|dbo)\s*\.\s*(?<name>\[[A-Za-z_][A-Za-z0-9_]*\]|[A-Za-z_][A-Za-z0-9_]*)(?=\s|\(|;|$)'
    $existingNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches((Get-AfifeSqlDefinitionText $PreviousSql), $definitionPattern, $options)) {
        [void]$existingNames.Add($match.Groups['name'].Value.Trim([char[]]'[]'))
    }
    $definitions = [Collections.Generic.List[object]]::new()
    foreach ($modulePath in $AddedModuleNames) {
        if ($modulePath -cnotmatch '^[0-9]{2}-[A-Za-z]+/[^/<>:]+\.sql$' -or $modulePath.Contains('..')) {
            throw "Unsupported new SQL path $modulePath. Use one canonical object file in its matching folder."
        }
        $path = Join-Path $ObjectRoot $modulePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $sql = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        $text = Get-AfifeSqlDefinitionText $sql
        foreach ($separator in [regex]::Matches($sql, '^\s*GO\s*(?:--.*)?$', $options)) {
            if (-not [regex]::IsMatch($text.Substring($separator.Index, $separator.Length),
                '^\s*GO\s*(?:--.*)?$', $options)) {
                throw "GO inside a quoted string/comment is not supported by the migration batch reader: $modulePath. Review this file explicitly."
            }
        }
        $matches = [regex]::Matches($text, $definitionPattern, $options)
        if ($modulePath.StartsWith('00-Prerequisites/', [StringComparison]::Ordinal) -or
            $modulePath.StartsWith('50-ReferenceData/', [StringComparison]::Ordinal)) {
            if ($matches.Count -gt 0) { throw "A routine definition cannot be hidden in prerequisite/seed file $modulePath." }
            # Additive columns/tables and seeded rows remain during rollback.
            continue
        }
        if ($matches.Count -ne 1) {
            throw "Cannot infer safe rollback for $modulePath. Expected one literal CREATE OR ALTER dbo trigger/procedure/function; review unsupported or multiple objects explicitly."
        }
        $match = $matches[0]
        $kind = $match.Groups['kind'].Value.ToUpperInvariant()
        if ($kind -eq 'PROC') { $kind = 'PROCEDURE' }
        $folder = switch ($kind) {
            'TRIGGER' { '30-Triggers/' }
            'PROCEDURE' { '20-StoredProcedures/' }
            'FUNCTION' { '10-Functions/' }
        }
        $name = $match.Groups['name'].Value.Trim([char[]]'[]')
        if (-not $modulePath.StartsWith($folder, [StringComparison]::Ordinal) -or
            $match.Groups['schema'].Value.Trim([char[]]'[]') -cne 'dbo' -or $name.Length -gt 128) {
            throw "Unsupported object/folder/schema in $modulePath. Use literal dbo and ASCII identifiers in the matching folder."
        }
        if (-not $existingNames.Add($name)) {
            throw "New SQL file $modulePath defines existing/duplicate dbo.$name; move or replace the existing canonical file explicitly instead."
        }
        foreach ($batch in [regex]::Split($text, '(?im)^\s*GO\s*(?:--.*)?$')) {
            if ([string]::IsNullOrWhiteSpace($batch)) { continue }
            if ([regex]::IsMatch($batch, $definitionPattern, $options)) {
                if ($batch.TrimStart() -cnotmatch '(?i)^CREATE\s+OR\s+ALTER\s+') {
                    throw "Object definition must start its SQL batch in $modulePath."
                }
            }
            elseif (-not [regex]::IsMatch($batch,
                '^\s*(?:SET\s+(?:ANSI_NULLS|QUOTED_IDENTIFIER|ANSI_PADDING|ANSI_WARNINGS|ARITHABORT|CONCAT_NULL_YIELDS_NULL|NUMERIC_ROUNDABORT|XACT_ABORT)\s+(?:ON|OFF)\s*;?\s*)+$', $options)) {
                throw "Unreviewed extra SQL batch in $modulePath. Safe automatic rollback supports a single routine plus SET options only."
            }
        }
        $definitions.Add([pscustomobject]@{ Kind = $kind; Name = $name; Path = $modulePath })
    }
    $before = [Collections.Generic.List[string]]::new()
    $after = [Collections.Generic.List[string]]::new()
    # Triggers must disappear before EF Down can archive newly added columns.
    # Procedures/functions disappear after old definitions have been restored;
    # reverse creation order retains ordinary module dependency ordering.
    foreach ($kind in @('TRIGGER', 'PROCEDURE', 'FUNCTION')) {
        for ($index = $definitions.Count - 1; $index -ge 0; $index--) {
            $definition = $definitions[$index]
            if ($definition.Kind -ne $kind) { continue }
            $drop = "DROP $kind IF EXISTS [dbo].[$($definition.Name)];"
            if ($kind -eq 'TRIGGER') { $before.Add($drop) }
            else { $after.Add($drop) }
        }
    }
    return [pscustomobject]@{
        BeforeSql = $before -join [Environment]::NewLine
        AfterSql = $after -join [Environment]::NewLine
        Count = $definitions.Count
    }
}

function Read-AfifeSqlSection(
    [string] $VersionRoot,
    [string] $Version,
    [ValidateSet('UP', 'DOWN', 'SEED', 'CANONICAL', 'REFERENCES')] [string] $Section,
    [string[]] $Visited = @()
) {
    if ($Version -cnotmatch '^[A-Za-z0-9_]+$') { throw 'Invalid SQL package version.' }
    $Section = $Section.ToUpperInvariant()
    $key = "$Version/$Section"
    if ($Visited -ccontains $key) { throw "Circular SQL package reference: $key" }
    $path = Join-Path $VersionRoot "$Version.sql"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "SQL package is missing: $path"
    }
    $source = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $options = [Text.RegularExpressions.RegexOptions]::Multiline -bor
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $inline = [regex]::Matches($source,
        "^-- <AFIFE:$Section>\r?\n(?<sql>[\s\S]*?)\r?\n-- </AFIFE:$Section>\r?$", $options)
    $reference = [regex]::Matches($source,
        "^-- <AFIFE:${Section}:REFERENCE=(?<version>[A-Za-z0-9_]+):(?<section>UP|DOWN|SEED)>\r?$", $options)
    if ($inline.Count + $reference.Count -ne 1) {
        throw "Expected exactly one $Section section in $Version.sql."
    }
    if ($inline.Count -eq 1) { $sql = $inline[0].Groups['sql'].Value }
    else {
        $sql = Read-AfifeSqlSection $VersionRoot `
            $reference[0].Groups['version'].Value `
            $reference[0].Groups['section'].Value ($Visited + $key)
    }
    $hash = [regex]::Matches($source,
        "^-- <AFIFE:SHA256:${Section}=(?<hash>[A-F0-9]{64})>\r?$", $options)
    $lfMarker = [regex]::Matches($source,
        "^-- <AFIFE:SHA256-LF:${Section}(?=[=:>\s])", $options)
    $lfHash = [regex]::Matches($source,
        "^-- <AFIFE:SHA256-LF:${Section}=(?<raw>[A-F0-9]{64}):(?<hash>[A-F0-9]{64})>\r?$", $options)
    $validHash = $hash.Count -eq 1
    if ($validHash -and $lfMarker.Count -gt 0) {
        # Bind the canonical digest to the immutable raw header. Validate it
        # even when the raw payload still matches, so corrupt metadata is not
        # silently accepted. Historic raw-only packages stay strictly raw-only.
        $validHash = $lfMarker.Count -eq 1 -and $lfHash.Count -eq 1 -and
            $lfHash[0].Groups['raw'].Value -ceq $hash[0].Groups['hash'].Value -and
            $lfHash[0].Groups['hash'].Value -ceq (Get-AfifeSqlLfHash $sql)
    }
    elseif ($validHash) {
        $validHash = $hash[0].Groups['hash'].Value -ceq (Get-AfifeSqlHash $sql)
    }
    if (-not $validHash) {
        throw "SQL payload hash mismatch for $key. Historic migration SQL must not be edited."
    }
    $batches = [regex]::Matches($source,
        "^-- <AFIFE:BATCHES:${Section}=(?<count>[0-9]+)>\r?$", $options)
    if ($batches.Count -ne 1 -or [int]$batches[0].Groups['count'].Value -ne (Get-AfifeSqlBatchCount $sql)) {
        throw "SQL command batch count mismatch for $key."
    }
    return $sql
}

function Read-AfifeModuleManifest([string] $PackagePath) {
    $source = [IO.File]::ReadAllText($PackagePath, [Text.Encoding]::UTF8)
    $match = [regex]::Match($source,
        '(?m)^-- <AFIFE:MODULES>\r?\n(?<paths>[\s\S]*?)^-- </AFIFE:MODULES>\r?$')
    if (-not $match.Success) { throw "Canonical module manifest is missing: $PackagePath" }
    return @($match.Groups['paths'].Value -split '\r?\n' |
        Where-Object { $_ -cmatch '^-- [^<>]+\.sql$' } |
        ForEach-Object { $_.Substring(3) })
}

function New-AfifeSqlPackage(
    [string] $Version,
    [System.Collections.IDictionary] $Sections,
    [string[]] $ModuleNames = @()
) {
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("-- Immutable SQL package: $Version")
    $lines.Add('-- Generated with the EF migration. Edit canonical DatabaseObjects, not this history.')
    $lines.Add('-- SHA256 preserves original UTF-8 text; paired SHA256-LF tolerates CRLF/LF transport only.')
    if ($ModuleNames.Count -gt 0) {
        $lines.Add('-- <AFIFE:MODULES>')
        foreach ($module in $ModuleNames) { $lines.Add("-- $module") }
        $lines.Add('-- </AFIFE:MODULES>')
    }
    foreach ($name in @('SEED', 'CANONICAL', 'REFERENCES', 'UP', 'DOWN')) {
        if (-not $Sections.Contains($name)) { continue }
        $section = $Sections[$name]
        $rawHash = Get-AfifeSqlHash $section.Sql
        $lines.Add("-- <AFIFE:SHA256:${name}=$rawHash>")
        $lines.Add("-- <AFIFE:SHA256-LF:${name}=${rawHash}:$(Get-AfifeSqlLfHash $section.Sql)>")
        $lines.Add("-- <AFIFE:BATCHES:${name}=$(Get-AfifeSqlBatchCount $section.Sql)>")
        if ($section.Reference) {
            if ($section.Reference -cnotmatch '^[A-Za-z0-9_]+:(UP|DOWN|SEED)$') {
                throw "Invalid SQL package reference: $($section.Reference)"
            }
            $lines.Add("-- <AFIFE:${name}:REFERENCE=$($section.Reference)>")
        }
        else {
            $lines.Add("-- <AFIFE:$name>")
            # Adding one sentinel newline before the closing marker lets the
            # reader preserve even the payload's original trailing newlines.
            $lines.Add($section.Sql)
            $lines.Add("-- </AFIFE:$name>")
        }
    }
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Write-AfifeUtf8([string] $Path, [string] $Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
