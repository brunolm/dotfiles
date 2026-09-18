---
name: b-run-isolation
description: Use this skill when the user wants to run a prompt through an isolated CLI instance launched from a temporary folder. Triggers include "/b-run-isolation", "run this in isolation", "run this prompt isolated", "run claude on this from a temp folder", "run codex on this in isolation", or any phrasing pairing a prompt with running it in a clean/isolated/temporary environment. Everything after the trigger is the prompt (with optional leading "cli: X" / "model: X" / "effort: Y" overrides — the CLI defaults to the agent running this skill, effort to high). Creates a fresh temp folder, runs the CLI non-interactively there, relays the output verbatim, and reports any files the run left behind.
version: 1.0.0
model: haiku
effort: low
---

# Run a Prompt in Isolation

The text after `/b-run-isolation` is a prompt for a *separate* CLI instance. Do not answer it yourself — launch the CLI from a freshly created temporary folder so the run sees no project files, no project CLAUDE.md / AGENTS.md, and no repo context, then relay what it printed.

## Parsing the arguments

1. Check for optional overrides at the start of the arguments, in any order:
   - `cli: <claude|codex>` — default: whichever agent is running this skill.
   - `model: <name>` — default per CLI (see the table).
   - `effort: <level>` — default `high`. Claude accepts `low`, `medium`, `high`, `xhigh`, `max`; Codex accepts `minimal`, `low`, `medium`, `high`.
2. Everything remaining is the prompt, passed through verbatim. If the prompt is empty, ask the user what to run.

| CLI | Default model | Command |
|---|---|---|
| `claude` | `fable` | `claude -p --model <model> --effort <effort> '<prompt>'` |
| `codex` | `gpt-5.6-terra` | `codex exec --skip-git-repo-check -m <model> -c model_reasoning_effort=<effort> '<prompt>'` |

`--skip-git-repo-check` is required for Codex — the temp folder is not a trusted directory.

## Steps

1. Create a fresh temporary folder (unique per run) under the system temp directory.
2. From inside that folder, run the CLI command from the table. Use a generous command timeout (10 minutes) — non-interactive runs can be slow.
3. Show the child's output to the user verbatim (summarize around it if it's long, but keep the raw output available).
4. If the run created files in the temp folder, list them and give the user the folder path — don't delete them. If the folder is empty, remove it.

## Commands

PowerShell (escape `'` inside the prompt by doubling it):

```powershell
$runDir = Join-Path $env:TEMP ("agent-isolated-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDir | Out-Null
Push-Location $runDir
try {
    claude -p --model fable --effort high '<prompt>'
} finally {
    Pop-Location
    $leftovers = Get-ChildItem -LiteralPath $runDir -Force
    if ($leftovers) { $leftovers | ForEach-Object FullName } else { Remove-Item -LiteralPath $runDir }
}
```

If only a bash shell is available, the equivalent is:

```bash
dir=$(mktemp -d -t agent-isolated-XXXXXX)
(cd "$dir" && claude -p --model fable --effort high '<prompt>')
ls -A "$dir" && echo "$dir" || rmdir "$dir"
```
