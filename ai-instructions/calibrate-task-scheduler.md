# Calibrate Task Scheduler

Instructions for an agent setting up a new (or re-installed) Windows machine so its Task
Scheduler matches the tuning done on the MSI GE76 in August 2026. Goal: stop background
jobs from grabbing disk/CPU while working, and stop OneDrive from starting at all.

Everything here needs an **elevated** PowerShell (task changes under `\Microsoft\` require
admin). Verify each step after applying; vendors re-register their tasks on updates, so
this document is also the reference for re-applying after drift.

## 1. Disable

| Task | Why |
|---|---|
| `\Microsoft\VisualStudio\Updates\BackgroundDownload` | Pre-downloads VS updates every 3h; VS Installer still finds updates when opened |
| `\Microsoft\Windows\Chkdsk\ProactiveScan` | Online filesystem scan during maintenance; corruption still surfaces as a boot-time chkdsk |
| `\OneDrive Startup Task-<SID>` | OneDrive is not used on this machine and steals the PrintScreen hotkey from ShareX |
| `\OneDrive Standalone Update Task-<SID>` (one per user profile) | The updater relaunches OneDrive with `/updateInstalled /background` even when startup is off |
| `\OneDrive Reporting Task-<SID>` (one per user profile) | Telemetry, pointless once OneDrive is off |

OneDrive task names end with the SID of the profile that installed them, so match by
prefix. Disable everything OneDrive, remove its Run key, and mark it disabled in Windows'
startup approval list. The approval flag is keyed by name and survives OneDrive re-adding
its Run value, which it does on its own updates:

```powershell
Disable-ScheduledTask -TaskPath '\Microsoft\VisualStudio\Updates\' -TaskName 'BackgroundDownload'
Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Chkdsk\' -TaskName 'ProactiveScan'
Get-ScheduledTask | Where-Object { $_.TaskName -like 'OneDrive*' } | Disable-ScheduledTask
Remove-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name OneDrive -ErrorAction SilentlyContinue
$approved = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
Set-ItemProperty $approved -Name OneDrive -Type Binary -Value ([byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
Get-Process OneDrive, 'Microsoft.SharePoint', FileCoAuth -ErrorAction SilentlyContinue | Stop-Process -Force
```

In the StartupApproved value the first byte is `2` for enabled and `3` for disabled; this is
what the Settings > Apps > Startup toggle writes.

Reversing any of these is `Enable-ScheduledTask` with the same path and name.

## 2. Reschedule updaters to every 12 hours

The vendor updaters poll hourly (Firefox every 7h) and each launches a full process. Keep
the tasks, stretch the repetition interval to 12h and leave the other triggers (logon,
repetition duration) untouched.

| Task | Default | Wanted |
|---|---|---|
| `\MicrosoftEdgeUpdateTaskMachineUA` | every 1h | every 12h |
| `\GoogleSystem\GoogleUpdater\GoogleUpdaterTaskSystem<version>{<guid>}` | every 1h | every 12h |
| `\Mozilla\Firefox Background Update <SID> <hash>` | every 7h | every 12h |

Names carry versions, SIDs or hashes, so match by prefix. `Set-ScheduledTask` re-validates
the task principal, which is fine for these three:

```powershell
$updaters = Get-ScheduledTask | Where-Object {
  $_.TaskName -like 'MicrosoftEdgeUpdateTaskMachineUA' -or
  $_.TaskName -like 'GoogleUpdaterTaskSystem*' -or
  $_.TaskName -like 'Firefox Background Update*'
}
foreach ($task in $updaters) {
  $triggers = $task.Triggers
  foreach ($trigger in $triggers) {
    if ($trigger.Repetition.Interval) { $trigger.Repetition.Interval = 'PT12H' }
  }
  Set-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -Trigger $triggers | Out-Null
}
```

The OneDrive Standalone Update tasks were also moved to weekly (Saturday 04:00) before
OneDrive was disabled outright. With the tasks disabled the schedule is moot; only redo
this if OneDrive is ever wanted again.

## 3. Known pitfalls

- **Edge re-registers its updater tasks on every Edge update**, resetting the interval to
  hourly. Google and OneDrive do the same on their own updates. Re-run step 2 after noticing
  `every PT1H` in the verification below.
- **OneDrive re-creates its Run key** even with its tasks disabled (observed within weeks of
  removing it). The StartupApproved flag in step 1 is what actually keeps it from starting;
  check both in the verification.
- **Tasks owned by a deleted profile** (a `-<SID>` suffix that matches no local account)
  cannot be edited: Windows fails with `No mapping between account names and security IDs
  was done`. They cannot run either. Disable them if allowed, otherwise leave them or
  `Unregister-ScheduledTask` them; they cannot be re-registered afterwards.
- `Chkdsk\SyspartRepair` is a different task, event-triggered, and stays enabled on purpose.
- The `Microsoft-Windows-TaskScheduler/Operational` log is off by default, so there is no run
  duration history to judge tasks by; classify by what the action runs.

## 4. Reviewed and deliberately left enabled

These were flagged as heavy in the same review and the owner chose to keep them. Ask before
touching them: `Defrag\ScheduledDefrag`, `Servicing\StartComponentCleanup`,
`DiskCleanup\SilentCleanup`, `Maintenance\WinSAT`, `Shell\IndexerAutomaticMaintenance`,
the `UpdateOrchestrator\*` tasks, `Speech\SpeechModelDownloadTask`, `SoftLandingDeferralTask`.

## 5. Verify

```powershell
$names = 'BackgroundDownload', 'ProactiveScan', 'OneDrive*', 'MicrosoftEdgeUpdateTaskMachineUA', 'GoogleUpdaterTaskSystem*', 'Firefox Background Update*'
Get-ScheduledTask | Where-Object { $n = $_.TaskName; $names | Where-Object { $n -like $_ } } | ForEach-Object {
  $interval = ($_.Triggers | ForEach-Object { $_.Repetition.Interval } | Where-Object { $_ }) -join ','
  '{0,-9} {1}{2}  {3}' -f $_.State, $_.TaskPath, $_.TaskName, $interval
}
```

Expected: the disable list shows `Disabled` and the three updaters show `PT12H`. For OneDrive
startup, check both keys:

```powershell
(Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).OneDrive
(Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run').OneDrive[0]
```

The first should be empty and the second should print `3`. If the Run value is back but the
approval byte is `3`, OneDrive is still blocked from starting; if the byte is `2`, redo step 1.
