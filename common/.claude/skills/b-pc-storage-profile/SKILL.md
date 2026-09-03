---
name: b-pc-storage-profile
description: Use this skill when the user wants to view, apply, or edit the NVMe/PCIe storage power presets managed by the `B-PC-Set-StorageProfile` alias. Triggers include "/b-pc-storage-profile", "storage profile status", "apply nvme-safe", "set storage power to original", "why is my NVMe going to sleep", "change the disk idle timeout in the preset", "add a storage preset", or any phrasing pairing NVMe / PCIe ASPM / disk idle settings with the power plan. Takes an optional argument — `status` (default), `nvme-safe`, `power`, `original` — and runs the alias; requests to change what a preset contains are handled by editing the preset tables in the dotfiles repo.
version: 1.0.0
---

# Storage Power Profile

`B-PC-Set-StorageProfile` lives in `windows/aliases/pc/power-storage.ps1` in the dotfiles repo, with the shared `PCPower-*` plumbing in `power-common.ps1`, and is loaded by the PowerShell profile. It writes the NVMe idle timeouts, thresholds, NOPPME, PCIe ASPM, and hard-disk idle settings of the active power scheme via `powercfg`, then prints a status table.

## Presets

| Preset | AC behavior | Why |
|---|---|---|
| `nvme-safe` | ASPM off, disk never sleeps, NVMe idle 60 s, thresholds 0 | Keeps the drive awake. Fixes the storport wake-stall bugcheck (0x124 / 0x154) |
| `power` | ASPM moderate, disk idle 15 min, NVMe idle 60 s | Relaxed but still avoids the 200 ms stock idle |
| `original` | Windows/OEM stock | Restore point |

DC values are stock in every preset; parking the drive on battery is a real saver and the stall only shows on AC.

## Steps

1. `status` (or no argument): run the status command and show the table. Nothing changes.
2. Applying a preset needs an elevated shell. The alias checks and refuses otherwise; tell the user to run `B-PC-Start-Powershell -Elevated` and retry if that happens.
3. After applying, the alias prints the table again. Confirm every row reads `scheme` in the Source column and the values match the preset. Report any `rejected` warnings verbatim.
4. `-AllSchemes` applies the preset to every power scheme, not just the active one. Only use it when the user asks.

## Commands

From a shell that has the profile loaded:

```powershell
B-PC-Set-StorageProfile status
B-PC-Set-StorageProfile nvme-safe
B-PC-Set-StorageProfile original -AllSchemes
```

From a bare `powershell -NoProfile` shell, dot-source the alias folder first:

```powershell
Get-ChildItem C:\BrunoLM\Projects\dotfiles\windows\aliases\pc\*.ps1 | ForEach-Object { . $_.FullName }; B-PC-Set-StorageProfile status
```

## Editing what a preset contains

When the user wants different values or a new preset, edit `windows/aliases/pc/power-storage.ps1`, not the machine directly:

- `PCStorage-Settings` maps each key to its subgroup GUID, setting GUID, label, and display unit. Add a row here to manage a new setting.
- `PCStorage-Presets` holds one `@(AC, DC)` pair per key per preset. Add a new preset as another entry and add its name to the `ValidateSet` on `B-PC-Set-StorageProfile`.
- The NVMe settings are hidden attributes. Look them up with `powercfg /qh SCHEME_CURRENT <subgroup GUID>` to see valid ranges before choosing values.

After editing, dot-source the file, run `status`, and apply the preset to verify nothing is rejected. Keep the Windows alias folder as the single source; there is no WSL counterpart since `powercfg` is Windows-only.
