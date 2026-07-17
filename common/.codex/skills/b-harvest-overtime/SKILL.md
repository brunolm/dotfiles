---
name: b-harvest-overtime
description: Use this skill when the user wants to know their Harvest overtime for a month. Triggers include "/b-harvest-overtime", "harvest overtime", "harvest overtime for June", "am I ahead or behind on my harvest hours this month", or any phrasing pairing Harvest with overtime / hour balance. Assumes 8h of work per workday (Mon-Fri). For the current month it counts from the 1st through yesterday - today is excluded unless the user explicitly asks to include it; for a past month it counts the whole month. Pulls tracked time from the Harvest MCP, compares it against expected hours, and reports the overtime (or deficit) with a per-day breakdown on request. Accepts an optional month argument like "june", "2026-06", or "last month"; default is the current month.
version: 1.0.0
allowed-tools:
  - mcp__harvest__get_time_report
  - mcp__harvest__list_time_entries
  - mcp__harvest__get_running_timer
  - PowerShell
---

# Harvest overtime (8h/workday baseline)

Compare the time tracked in Harvest against an expected **8 hours per workday (Mon-Fri)** and report the overtime or deficit. This skill only **reads** from Harvest - it never creates, updates, or deletes anything.

## 1. Resolve the month (argument)

The optional argument - the text after the skill name - names the month, matched case-insensitively:

- **(omitted)** - the current month.
- **`2026-06`** / **`06/2026`** - that year-month.
- **`june`** / **`jun`** - that month in the current year; if that month hasn't started yet this year, assume the most recent past occurrence and say so.
- **`june 2025`** - that month in that year.
- **`last month`** - the previous calendar month.

The argument (or the user's phrasing) may also say to count today - e.g. **`including today`**, **`with today`**, **`count today`**. That only matters for the current month; see step 2.

Anything unparseable: fall back to the current month and note in one line that the argument wasn't recognized.

## 2. Compute the period and expected hours

The period is:

- **Current month** -> from the 1st **through yesterday** - today is still in progress and is **excluded**, unless the user explicitly asks to include it (e.g. "including today", "count today"), in which case the period runs through today and today counts as a full expected workday. If today is the 1st and today isn't included, there's nothing to measure yet; say so and stop.
- **Past month** -> from the 1st through the last day of that month.
- **Future month** -> nothing to measure; say so and stop.

Do all date math and workday counting in PowerShell - never by hand:

```powershell
# Set $y/$m from step 1 (current month when no argument)
# Set $includeToday = $true only if the user explicitly asked to count today
$includeToday = $false
$today = (Get-Date).Date
$start = Get-Date -Year $y -Month $m -Day 1
$start = $start.Date
$isCurrent = ($start.Year -eq $today.Year -and $start.Month -eq $today.Month)
$end = if ($isCurrent) { $includeToday ? $today : $today.AddDays(-1) } else { $start.AddMonths(1).AddDays(-1) }
if ($end -lt $start) { 'Nothing to measure yet - the month just started.'; return }

$workdays = 0
for ($d = $start; $d -le $end; $d = $d.AddDays(1)) {
  if ($d.DayOfWeek -notin 'Saturday','Sunday') { $workdays++ }
}

[pscustomobject]@{
  Start    = $start.ToString('yyyy-MM-dd')
  End      = $end.ToString('yyyy-MM-dd')
  Workdays = $workdays
  ExpectedHours = $workdays * 8
} | ConvertTo-Json
```

Holidays and days off are **not** excluded - every Mon-Fri counts. If the user mentions specific days off (e.g. "I was off on the 4th"), subtract those from `Workdays` and say you did.

## 3. Pull the tracked time from Harvest

1. Call `get_time_report` with the `from` / `to` dates from step 2 to get the total tracked hours for the period. If the report only returns per-project/per-day buckets, sum them.
2. If the period includes today, call `get_running_timer` - a **running** timer's elapsed time may not be in the report yet. If one is running and it started within the period and isn't already counted, add its elapsed time to the total. Mention that a running timer was included.

If `get_time_report` can't produce a plain total, fall back to `list_time_entries` for the range and sum the durations. Harvest durations are **decimal hours** (e.g. `1.75` = 1h 45m), not seconds - don't convert as if they were seconds.

## 4. Compute and report the overtime

Compute in PowerShell (feed in the tracked total in decimal hours):

```powershell
$tracked = [timespan]::FromHours($trackedHours)
$expected = [timespan]::FromHours($expectedHours)
$diff = $tracked - $expected
[pscustomobject]@{
  Tracked  = '{0}h {1:mm}m' -f [int][math]::Floor($tracked.TotalHours), $tracked
  Expected = '{0}h' -f $expectedHours
  Diff     = ('{0}{1}h {2:mm}m' -f ($diff -lt [timespan]::Zero ? '-' : '+'), [int][math]::Floor([math]::Abs($diff.TotalHours)), $diff)
} | ConvertTo-Json
```

Then report a short summary:

- **Period** - `Start .. End` and whether it's month-to-date or the full month.
- **Workdays** - count, and the expected hours (`workdays x 8h`).
- **Tracked** - total tracked time.
- **Result** - one plain sentence leading the answer: `+Xh Ym overtime` or `-Xh Ym short`. If the diff is within +/-5 minutes, call it even.

Only produce a per-day breakdown (a table of date, tracked, +/-diff vs 8h, weekends marked) if the user asks for it - that needs `list_time_entries` or a day-grouped `get_time_report`.
