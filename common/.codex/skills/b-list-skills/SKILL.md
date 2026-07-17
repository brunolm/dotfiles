---
name: b-list-skills
description: Use this skill when the user wants to see all of their personal `b-` prefixed skills in one place. Triggers include "/b-list-skills", "list my brunolm skills", "what brunolm skills do I have", "show my skills", "list my skills in a table", or any phrasing that pairs listing/inventorying skills with the b- prefix. Scans the installed Codex skill directories, reads each SKILL.md frontmatter, filters to names starting with `b-`, and prints a table of skill name + what it does.
version: 1.0.0
allowed-tools:
  - PowerShell
---

# List b- Skills

Show every skill whose name starts with `b-` in a table: the skill name and a concise description of what it does.

## Steps

1. Use PowerShell to gather the skills.
2. Resolve the Codex home directory:
   - Prefer `$env:CODEX_HOME` if set.
   - Otherwise use `$env:USERPROFILE\.codex`.
3. Scan for `SKILL.md` files under `<codexHome>\skills` (recursively).
4. For each `SKILL.md`, parse the YAML frontmatter and read `name` and `description`.
5. Keep only skills whose `name` starts with `b-`.
6. Present the result to the user as a Markdown table with two columns:
   - **Skill** — the `name`.
   - **What it does** — a short, plain-language summary (one line). Derive this from the `description`, stripping the boilerplate trigger text ("Use this skill when...", "Triggers include...") down to the core action.
7. Sort rows alphabetically by skill name. If none are found, report the Codex home used and the directory checked.

## PowerShell

Use this command to collect the raw skill data, then render the table yourself:

```powershell
$codexHome = if ($env:CODEX_HOME) {
    [Environment]::ExpandEnvironmentVariables($env:CODEX_HOME)
} else {
    Join-Path $env:USERPROFILE '.codex'
}

$skillsRoot = Join-Path $codexHome 'skills'

if (-not (Test-Path -LiteralPath $skillsRoot)) {
    [pscustomobject]@{ CodexHome = $codexHome; Checked = $skillsRoot; Result = 'skills directory not found' } | Format-List
    return
}

Get-ChildItem -LiteralPath $skillsRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        $lines = Get-Content -LiteralPath $_.FullName
        $inFront = $false
        $name = $null
        $desc = $null
        foreach ($line in $lines) {
            if ($line -eq '---') {
                if (-not $inFront) { $inFront = $true; continue } else { break }
            }
            if ($inFront -and $line -match '^name:\s*(.+)$') { $name = $matches[1].Trim() }
            if ($inFront -and $line -match '^description:\s*(.+)$') { $desc = $matches[1].Trim() }
        }
        if ($name -like 'b-*') {
            [pscustomobject]@{ Name = $name; Description = $desc }
        }
    } |
    Sort-Object Name |
    Format-List
```
