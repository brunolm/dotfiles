---
name: list-ai-logs
description: Use this skill when the user asks to list, find, inspect, inventory, or report AI CLI log files, transcript/session JSONL files, or the file size of Claude Code / Codex logs. Lists local agent log-like files with exact byte counts and human-readable sizes without reading log contents unless the user explicitly asks.
version: 1.0.0
model: haiku
allowed-tools:
  - PowerShell
---

# List AI Logs

List agent log-like files and the size of each file. Do not read or print log contents unless the user explicitly asks for contents.

## Steps

1. Use PowerShell.
2. Resolve every agent home directory that exists:
   - Claude: `$env:CLAUDE_CONFIG_DIR` if set, otherwise `$env:USERPROFILE\.claude`.
   - Codex: `$env:CODEX_HOME` if set, otherwise `$env:USERPROFILE\.codex`.
3. Search these log/session locations under each agent home:
   - the agent home root
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
   - agent
   - full path
   - size in bytes
   - human-readable size
   - last write time
6. Also print the total file count and total size, per agent and overall.
7. If no files are found, report the agent homes used and the candidate directories checked.

## PowerShell

Use this command as the default implementation:

```powershell
$agentHomes = [ordered]@{
    Claude = if ($env:CLAUDE_CONFIG_DIR) {
        [Environment]::ExpandEnvironmentVariables($env:CLAUDE_CONFIG_DIR)
    } else {
        Join-Path $env:USERPROFILE '.claude'
    }
    Codex  = if ($env:CODEX_HOME) {
        [Environment]::ExpandEnvironmentVariables($env:CODEX_HOME)
    } else {
        Join-Path $env:USERPROFILE '.codex'
    }
}

function Format-LogSize {
    param([long] $Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

$logExtensions = '.log', '.jsonl', '.ndjson'
$checkedDirectories = @()
$files = @()

foreach ($agent in $agentHomes.Keys) {
    $agentHome = $agentHomes[$agent]
    if (-not (Test-Path -LiteralPath $agentHome)) { continue }

    $candidateRoots = @(
        $agentHome,
        (Join-Path $agentHome 'debug'),
        (Join-Path $agentHome 'daemon'),
        (Join-Path $agentHome 'logs'),
        (Join-Path $agentHome 'projects'),
        (Join-Path $agentHome 'sessions'),
        (Join-Path $agentHome 'telemetry')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique

    $checkedDirectories += $candidateRoots

    $found = Get-ChildItem -LiteralPath $agentHome -File -ErrorAction SilentlyContinue

    foreach ($root in ($candidateRoots | Where-Object { $_ -ne $agentHome })) {
        $found += Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue
    }

    $files += $found |
        Where-Object { $_.Extension -in $logExtensions } |
        Sort-Object FullName -Unique |
        Select-Object @{ Name = 'Agent'; Expression = { $agent } }, FullName, Length, LastWriteTime
}

if (-not $files) {
    [pscustomobject]@{
        AgentHomes = (($agentHomes.Keys | ForEach-Object { "$_=$($agentHomes[$_])" }) -join '; ')
        CheckedDirectories = ($checkedDirectories -join '; ')
        Result = 'No agent log-like files found'
    } | Format-List
    return
}

$files |
    Sort-Object Agent, FullName |
    Select-Object Agent, FullName,
        @{ Name = 'SizeBytes'; Expression = { $_.Length } },
        @{ Name = 'Size'; Expression = { Format-LogSize $_.Length } },
        LastWriteTime |
    Format-Table -AutoSize

$files |
    Group-Object Agent |
    ForEach-Object {
        $groupBytes = [long](($_.Group | Measure-Object -Property Length -Sum).Sum)
        [pscustomobject]@{
            Agent = $_.Name
            FileCount = $_.Count
            TotalBytes = $groupBytes
            TotalSize = Format-LogSize $groupBytes
        }
    } |
    Format-Table -AutoSize

$totalBytes = [long](($files | Measure-Object -Property Length -Sum).Sum)
[pscustomobject]@{
    FileCount = $files.Count
    TotalBytes = $totalBytes
    TotalSize = Format-LogSize $totalBytes
} | Format-List
```
