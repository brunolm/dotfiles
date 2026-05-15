---
name: list-ai-logs
description: Use this skill when the user asks Codex to list, find, inspect, inventory, or report Codex log files, transcript/session JSONL files, or the file size of Codex logs. Lists local Codex log-like files with exact byte counts and human-readable sizes without reading log contents unless the user explicitly asks.
version: 1.0.0
allowed-tools:
  - PowerShell
---

# List AI Logs

List Codex log-like files and the size of each file. Do not read or print log contents unless the user explicitly asks for contents.

## Steps

1. Use PowerShell.
2. Resolve the Codex home directory:
   - Prefer `$env:CODEX_HOME` if it is set.
   - Otherwise use `$env:USERPROFILE\.codex`.
3. Search known Codex log/session locations under the Codex home directory:
   - the Codex home root
   - `debug`
   - `daemon`
   - `logs`
   - `projects`
   - `sessions`
   - `telemetry`
4. Include files with these log-like extensions:
   - `.log`
   - `.jsonl`
   - `.ndjson`
5. Print a table with:
   - full path
   - size in bytes
   - human-readable size
   - last write time
6. Also print the total file count and total size.
7. If no files are found, report the Codex home used and the candidate directories checked.

## PowerShell

Use this command as the default implementation:

```powershell
$codexHome = if ($env:CODEX_HOME) {
    [Environment]::ExpandEnvironmentVariables($env:CODEX_HOME)
} else {
    Join-Path $env:USERPROFILE '.codex'
}

$candidateRoots = @(
    $codexHome,
    (Join-Path $codexHome 'debug'),
    (Join-Path $codexHome 'daemon'),
    (Join-Path $codexHome 'logs'),
    (Join-Path $codexHome 'projects'),
    (Join-Path $codexHome 'sessions'),
    (Join-Path $codexHome 'telemetry')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique

function Format-LogSize {
    param([long] $Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

$files = @()

if (Test-Path -LiteralPath $codexHome) {
    $files += Get-ChildItem -LiteralPath $codexHome -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.jsonl', '.ndjson' }
}

foreach ($root in ($candidateRoots | Where-Object { $_ -ne $codexHome })) {
    $files += Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.jsonl', '.ndjson' }
}

$files = $files | Sort-Object FullName -Unique

if (-not $files) {
    [pscustomobject]@{
        CodexHome = $codexHome
        CheckedDirectories = ($candidateRoots -join '; ')
        Result = 'No Codex log-like files found'
    } | Format-List
    return
}

$files |
    Select-Object FullName,
        @{ Name = 'SizeBytes'; Expression = { $_.Length } },
        @{ Name = 'Size'; Expression = { Format-LogSize $_.Length } },
        LastWriteTime |
    Format-Table -AutoSize

$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
[pscustomobject]@{
    FileCount = $files.Count
    TotalBytes = $totalBytes
    TotalSize = Format-LogSize $totalBytes
} | Format-List
```
