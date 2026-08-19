---
name: b-time
description: Use this skill when the user wants to track work hours with their self-hosted time log. Triggers include "/b-time", "start tracking", "punch in", "punch out", "stop the timer", "am I tracking time", "time status", "time report for june", "how many hours did I work this month", logging finished ranges like "10am +8h" / "10am ~ 5pm" / "10am ~ 1pm 5pm ~ 8pm", clearing a day like "reset today" / "clear yesterday" / "clear 2026-07-10", or any phrasing pairing time tracking with start/stop/status/report/log/clear - as long as Toggl or Harvest is NOT named (those have their own tools). Wraps the time.ps1 CLI in the local time-tracking repo: entries are stored as monthly JSONL files and synced via git. After a log/stop adds finished time, it also mirrors the new entries to Toggl and Harvest via their MCPs (with one confirmation before writing).
version: 1.2.0
allowed-tools:
  - Read
  - PowerShell
  - mcp__toggl__list_time_entries
  - mcp__toggl__start_time_entry
  - mcp__toggl__update_time_entry
  - mcp__harvest__list_time_entries
  - mcp__harvest__log_time
---

# Time tracking (self-hosted)

Drive the CLI at **`C:\BrunoLM\Projects\time-tracking\time.ps1`** - entries live in that repo as `<yyyy>/<yyyy-MM>.jsonl` (one JSON entry per line; `end: null` marks the running timer) and every mutation commits, pulling/pushing automatically when an `origin` remote exists. Never edit the JSONL by hand unless the user explicitly asks to fix an entry.

## Always run it with PowerShell 7

The script uses PowerShell 7 syntax (the `? :` ternary and `??`), so Windows PowerShell 5.1 fails to even parse it - `powershell` / `powershell.exe` is 5.1 and must never be used here. Always invoke it as `pwsh -NoProfile -File '<script>' <args>`, which is correct from any shell (Bash tool, cmd, a 5.1 session, or the PowerShell tool) because it launches PowerShell 7 as its own process.

## Subcommands

Map the user's intent to one of:

```powershell
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' start [project] [note...]
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' stop
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' status
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' report -Month yyyy-MM
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' log [project] [note...] -Start HH:mm -End HH:mm [-Date yyyy-MM-dd] [-Force]
pwsh -NoProfile -File 'C:\BrunoLM\Projects\time-tracking\time.ps1' clear [-Date yyyy-MM-dd]
```

- **start** - begin a timer. Pass the project and note if the user gave them (e.g. "start tracking acme, fixing the api" -> `start acme fixing the api`). The script refuses if a timer is already running - relay that message.
- **stop** - close the running timer; the script prints the tracked duration.
- **status** - the running timer (if any) plus today's total.
- **report** - a two-column per-day table (date, hours) plus a Total line and an Overtime line (total vs 8h per Mon-Fri workday; the current month counts workdays through today). Resolve the month argument the same way as other skills: omitted -> current month; `june` / `2026-06` / `last month` -> that month, as `yyyy-MM`.
- **log** - record finished ranges after the fact. Normalize the user's phrasing into 24h `-Start`/`-End` times, one `log` call per range:
  - `10am +8h` -> `-Start 10:00 -End 18:00` (end = start + duration)
  - `10am ~ 5pm` -> `-Start 10:00 -End 17:00`
  - `10am ~ 1pm 5pm ~ 8pm` -> two calls: `-Start 10:00 -End 13:00`, then `-Start 17:00 -End 20:00`
  - a date word ("yesterday 10am ~ 5pm", "on the 10th") -> add `-Date yyyy-MM-dd`; omitted means today
  - an end at/before the start is treated as overnight (rolls into the next day). The script refuses ranges overlapping existing entries - relay the message and only re-run with `-Force` if the user confirms.
- **clear** - "reset today" / "clear today" -> `clear`; "reset yesterday" / "clear yesterday" / "clear <date>" -> `clear -Date yyyy-MM-dd`. Removes every entry for that day; tell the user how many were removed and that git history can recover them.

## Syncing to Toggl and Harvest

After any change that adds finished time - a `log` call or a `stop` - mirror the new entries to Toggl and Harvest via their MCP tools. The sync is part of this skill's contract, so do it even though the user didn't name those services, but keep the global rule: show a summary and ask permission before writing (one confirmation covering both services). Skip the sync entirely for `start`, `status`, `report`, and `clear` (deletions/fixes are not auto-synced - just tell the user the services may now disagree).

1. Read **`C:\BrunoLM\Projects\dotfiles\local\b-time-info.md`** (gitignored - it holds the workspace/project/task ids; never hardcode them here). Expected content:

   ```markdown
   # b-time sync info

   ## Toggl

   - **Workspace ID:** <id>
   - **Project ID:** <id>
   - **Project name:** <name>

   ## Harvest

   - **Project ID:** <id>
   - **Task ID:** <id>
   - **Task name:** <name>
   - **Project name:** <name>
   ```

   If the file is missing (or an id in it no longer resolves), discover the values from each service's recent entries / project lists, confirm them with the user, and offer to save them to the file in this format.
2. Dedupe: `mcp__toggl__list_time_entries` and `mcp__harvest__list_time_entries` over the affected dates; skip any entry whose day/range already exists in that service.
3. Create the entries with the ids from that file:
   - **Toggl** - the MCP has no create-completed tool: call `start_time_entry` with the entry's start as local-offset ISO time (e.g. `2026-07-30T10:00:00-03:00`), then `update_time_entry` setting `stop`. Sequence the pairs - never start the next entry before the previous one has its stop set.
   - **Harvest** - `log_time` with `spent_at` and decimal `hours` (duration-only, matching existing entries).
4. Report what was synced next to the local result, and call out anything skipped as a duplicate.

## Fixing entries

If the user asks to correct a forgotten stop or wrong time, edit the matching line in `<yyyy>/<yyyy-MM>.jsonl` directly (keep the `yyyy-MM-ddTHH:mm:sszzz` timestamp format and one compact JSON object per line), then commit in that repo with a short message like `fix: close forgotten timer` (and push if `origin` exists).

## Report output

Relay the script output conversationally - lead with the total (or the running timer for status), keep the per-day/per-project breakdown as a table only when the user wants detail.
