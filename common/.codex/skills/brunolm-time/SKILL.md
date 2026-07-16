---
name: brunolm-time
description: Use this skill when the user wants to track work hours with their self-hosted time log. Triggers include "/brunolm-time", "start tracking", "punch in", "punch out", "stop the timer", "am I tracking time", "time status", "time report for june", "how many hours did I work this month", logging finished ranges like "10am +8h" / "10am ~ 5pm" / "10am ~ 1pm 5pm ~ 8pm", clearing a day like "reset today" / "clear yesterday" / "clear 2026-07-10", or any phrasing pairing time tracking with start/stop/status/report/log/clear - as long as Toggl or Harvest is NOT named (those have their own tools). Wraps the time.ps1 CLI in the local time-tracking repo: entries are stored as monthly JSONL files and synced via git.
version: 1.0.0
allowed-tools:
  - Read
  - PowerShell
---

# Time tracking (self-hosted)

Drive the CLI at **`C:\BrunoLM\Projects\time-tracking\time.ps1`** - entries live in that repo as `<yyyy>/<yyyy-MM>.jsonl` (one JSON entry per line; `end: null` marks the running timer) and every mutation commits, pulling/pushing automatically when an `origin` remote exists. Never edit the JSONL by hand unless the user explicitly asks to fix an entry.

## Subcommands

Map the user's intent to one of:

```powershell
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' start [project] [note...]
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' stop
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' status
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' report -Month yyyy-MM
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' log [project] [note...] -Start HH:mm -End HH:mm [-Date yyyy-MM-dd] [-Force]
& 'C:\BrunoLM\Projects\time-tracking\time.ps1' clear [-Date yyyy-MM-dd]
```

- **start** - begin a timer. Pass the project and note if the user gave them (e.g. "start tracking acme, fixing the api" -> `start acme fixing the api`). The script refuses if a timer is already running - relay that message.
- **stop** - close the running timer; the script prints the tracked duration.
- **status** - the running timer (if any) plus today's total.
- **report** - per-day and per-project totals with a grand total. Resolve the month argument the same way as other skills: omitted -> current month; `june` / `2026-06` / `last month` -> that month, as `yyyy-MM`.
- **log** - record finished ranges after the fact. Normalize the user's phrasing into 24h `-Start`/`-End` times, one `log` call per range:
  - `10am +8h` -> `-Start 10:00 -End 18:00` (end = start + duration)
  - `10am ~ 5pm` -> `-Start 10:00 -End 17:00`
  - `10am ~ 1pm 5pm ~ 8pm` -> two calls: `-Start 10:00 -End 13:00`, then `-Start 17:00 -End 20:00`
  - a date word ("yesterday 10am ~ 5pm", "on the 10th") -> add `-Date yyyy-MM-dd`; omitted means today
  - an end at/before the start is treated as overnight (rolls into the next day). The script refuses ranges overlapping existing entries - relay the message and only re-run with `-Force` if the user confirms.
- **clear** - "reset today" / "clear today" -> `clear`; "reset yesterday" / "clear yesterday" / "clear <date>" -> `clear -Date yyyy-MM-dd`. Removes every entry for that day; tell the user how many were removed and that git history can recover them.

## Fixing entries

If the user asks to correct a forgotten stop or wrong time, edit the matching line in `<yyyy>/<yyyy-MM>.jsonl` directly (keep the `yyyy-MM-ddTHH:mm:sszzz` timestamp format and one compact JSON object per line), then commit in that repo with a short message like `fix: close forgotten timer` (and push if `origin` exists).

## Report output

Relay the script output conversationally - lead with the total (or the running timer for status), keep the per-day/per-project breakdown as a table only when the user wants detail.
