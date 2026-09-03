---
name: b-pc-cpu-profile
description: Use this skill when the user wants to view, apply, or edit the CPU power presets managed by the `B-PC-Set-CpuProfile` alias. Triggers include "/b-pc-cpu-profile", "cpu profile status", "set cpu to cool", "apply the perf profile", "my laptop is hot, switch to cool", "go back to the default cpu profile", "change the EPP in the cool preset", "add a cpu preset", or any phrasing pairing CPU turbo / energy preference / max processor state / thread scheduling / Windows power mode with a preset. Takes an optional argument — `status` (default), `cool`, `balanced`, `perf`, `default` — and runs the alias; requests to change what a preset contains are handled by editing the preset tables in the dotfiles repo.
version: 1.0.0
---

# CPU Power Profile

`B-PC-Set-CpuProfile` lives in `windows/aliases/pc/power-cpu.ps1` in the dotfiles repo, with the shared `PCPower-*` plumbing in `power-common.ps1`, and is loaded by the PowerShell profile. It writes the processor settings of the active power scheme via `powercfg`, sets the Windows power-mode overlay (the Settings > Power slider), and prints a status table.

The CPU runs in HWP autonomous mode, so these are the knobs that actually matter. Class 0 is the E-cores and class 1 is the P-cores; the P-core override wins, so a cap set only on the base setting never reaches the hot cores.

## Presets

| Preset | Turbo | EPP (AC) | Max state E/P | Scheduling | Power mode | Use |
|---|---|---|---|---|---|---|
| `cool` | Disabled | 60% | 95 / 95 | Prefer E-cores | Balanced | Video, browsing, hot room |
| `balanced` | Efficient Enabled | 50% | 95 / 95 | Automatic | Balanced | Daily driver with turbo for sustained work |
| `perf` | Aggressive | 20% | 100 / 100 | Automatic | Best performance | Games, builds |
| `default` | Disabled | 45% | 95 / 100 | Automatic | Best performance | Machine baseline captured 2026-09-03 |

Higher EPP favors efficiency. `cool` also sets the cooling policy to passive and halves the latency hint so keyboard/mouse input doesn't spike the clock.

## Steps

1. `status` (or no argument): run the status command and show the table. Nothing changes.
2. Applying a preset needs an elevated shell. The alias checks and refuses otherwise; tell the user to run `B-PC-Start-Powershell -Elevated` and retry if that happens.
3. After applying, the alias prints the table again. Confirm the values match the preset and the `Power mode (overlay)` row matches. Report any `rejected` warnings verbatim.
4. If the user asked because the machine is hot, follow up with a quick reading so the effect is visible: `\Energy Meter(rapl_package0_pkg)\Power` for package watts and the `Processor Information` counters for clock. The `b-pc-turbo-boost` skill has the snippet.
5. `-AllSchemes` applies the scheme settings to every power scheme. The overlay is global regardless. Only use it when the user asks.

## Commands

From a shell that has the profile loaded:

```powershell
B-PC-Set-CpuProfile status
B-PC-Set-CpuProfile cool
B-PC-Set-CpuProfile default
```

From a bare `powershell -NoProfile` shell, dot-source the alias folder first:

```powershell
Get-ChildItem C:\BrunoLM\Projects\dotfiles\windows\aliases\pc\*.ps1 | ForEach-Object { . $_.FullName }; B-PC-Set-CpuProfile status
```

## Editing what a preset contains

When the user wants different values or a new preset, edit `windows/aliases/pc/power-cpu.ps1`, not the machine directly:

- `PCCpu-Settings` maps each key to the `SUB_PROCESSOR` setting GUID, label, and display unit. Add a row here to manage a new setting. Enum-style settings need a matching case in `PCPower-Format` (in `power-common.ps1`).
- `PCCpu-Presets` holds one `@(AC, DC)` pair per key per preset plus a `PowerMode` key naming an entry of `PCCpu-PowerModes`. Add a new preset as another entry and add its name to the `ValidateSet` on `B-PC-Set-CpuProfile`.
- Option indexes for enum settings come from `powercfg /qh SCHEME_CURRENT SUB_PROCESSOR <GUID>`; percent settings are 0-100.

After editing, dot-source the file, run `status`, and apply the preset to verify nothing is rejected. Keep the Windows alias folder as the single source; there is no WSL counterpart since `powercfg` is Windows-only.
