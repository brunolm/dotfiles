---
name: list-ai-logs
description: Use this skill when the user asks Claude to list, find, inspect, inventory, or report Claude Code log files, transcript/session JSONL files, or the file size of Claude logs. Lists local Claude log-like files with exact byte counts and human-readable sizes without reading log contents unless the user explicitly asks.
version: 1.0.0
allowed-tools:
  - PowerShell
---

# List AI Logs

List Claude Code log-like files and the size of each file. Do not read or print log contents unless the user explicitly asks for contents.

## Steps

1. Use PowerShell.
2. Resolve the Claude home directory:
   - Prefer `$env:CLAUDE_CONFIG_DIR` if it is set.
   - Otherwise use `$env:USERPROFILE\.claude`.
3. Search known Claude log/session locations under the Claude home directory:
   - the Claude home root
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
7. If no files are found, report the Claude home used and the candidate directories checked.

## PowerShell

Use this command as the default implementation:

```powershell
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) {
    [Environment]::ExpandEnvironmentVariables($env:CLAUDE_CONFIG_DIR)
} else {
    Join-Path $env:USERPROFILE '.claude'
}

$candidateRoots = @(
    $claudeHome,
    (Join-Path $claudeHome 'debug'),
    (Join-Path $claudeHome 'daemon'),
    (Join-Path $claudeHome 'logs'),
    (Join-Path $claudeHome 'projects'),
    (Join-Path $claudeHome 'sessions'),
    (Join-Path $claudeHome 'telemetry')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique

function Format-LogSize {
    param([long] $Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

$files = @()

if (Test-Path -LiteralPath $claudeHome) {
    $files += Get-ChildItem -LiteralPath $claudeHome -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.jsonl', '.ndjson' }
}

foreach ($root in ($candidateRoots | Where-Object { $_ -ne $claudeHome })) {
    $files += Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.jsonl', '.ndjson' }
}

$files = $files | Sort-Object FullName -Unique

if (-not $files) {
    [pscustomobject]@{
        ClaudeHome = $claudeHome
        CheckedDirectories = ($candidateRoots -join '; ')
        Result = 'No Claude log-like files found'
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
