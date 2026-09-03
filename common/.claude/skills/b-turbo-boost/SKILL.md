---
name: b-turbo-boost
description: Use this skill when the user wants to view or change the CPU turbo boost mode of the active Windows power plan. Triggers include "/b-turbo-boost", "disable turbo", "enable turbo boost", "turn turbo off/on", "turbo status", "set boost mode to efficient", "is turbo on", or any phrasing pairing turbo/boost with the CPU or power plan. Takes one optional argument — `status` (default), `off`, `on`, `aggressive`, `efficient`, or `efficient-aggressive` — and applies it to both AC and DC of the active scheme via powercfg, then verifies the result and shows the current CPU clock and package power so the effect is visible immediately.
version: 1.0.0
---

# Toggle CPU Turbo Boost

Turbo boost is the `Processor performance boost mode` setting (`PERFBOOSTMODE`) under `SUB_PROCESSOR` in the Windows power plan. It is what lets the CPU run above its base clock. Disabling it roughly halves package power and drops temperatures on bursty work like video playback, at the cost of peak speed under heavy load. This setting is independent of `Maximum processor state` — a 95% cap does not stop turbo on modern Intel CPUs.

## Parsing the argument

| Argument | Index | Meaning |
|---|---|---|
| `status` (default) | – | Show the current AC/DC value and a live reading, change nothing |
| `off`, `disable`, `disabled` | 0 | Never boost. Coolest and quietest |
| `on`, `enable`, `enabled` | 1 | Boost when the OS asks for more performance |
| `aggressive` | 2 | Boost eagerly on any burst (Windows default) |
| `efficient`, `efficient-enabled` | 3 | Boost only when the work is sustained. Good daily-use middle ground |
| `efficient-aggressive` | 4 | Like aggressive, but backs off faster |

Anything else: show the table above and ask which one the user wants.

## Steps

1. If the argument is `status`, run the status block only.
2. Otherwise, check the shell is elevated. `powercfg /setacvalueindex` silently succeeds without admin on some builds but the value does not stick, so verify by reading it back. If not elevated, tell the user to run the command from an admin PowerShell (the `PC-Start-Powershell` alias opens one).
3. Apply the index to AC and DC of the active scheme, then re-activate the scheme. `powercfg` only writes the registry; the scheme must be re-applied for the change to take effect.
4. Read the value back and confirm it matches. If it does not, report the mismatch instead of claiming success.
5. Show the live reading so the user sees the effect: current CPU clock, package power if the `Energy Meter` counters exist, and a note that fans may take a minute to settle.

## Commands

Apply (replace `<index>` with the value from the table):

```powershell
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE <index>
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE <index>
powercfg /setactive SCHEME_CURRENT
```

Status:

```powershell
$names = @{ 0 = 'Disabled'; 1 = 'Enabled'; 2 = 'Aggressive'; 3 = 'Efficient Enabled'; 4 = 'Efficient Aggressive'; 5 = 'Aggressive At Guaranteed'; 6 = 'Efficient Aggressive At Guaranteed' }
$q = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE
foreach ($line in ($q | Select-String 'Current (AC|DC) Power Setting Index')) {
  $idx = [int]($line -replace '.*: 0x', '0x')
  '{0}: {1} ({2})' -f ($line -replace '.*Current (AC|DC).*', '$1'), $idx, $names[$idx]
}

$perf = (Get-Counter '\Processor Information(_Total)\% Processor Performance', '\Processor Information(_Total)\Processor Frequency').CounterSamples
'CPU clock: {0:N0} MHz' -f ($perf[0].CookedValue * $perf[1].CookedValue / 100)
try { 'Package power: {0:N1} W' -f ((Get-Counter '\Energy Meter(rapl_package0_pkg)\Power' -ErrorAction Stop).CounterSamples[0].CookedValue / 1000) } catch { 'Package power: not exposed on this machine' }
```

## Notes

- `PERFBOOSTMODE` is a hidden attribute, so it does not appear in the Control Panel UI unless unhidden once: `powercfg -attributes SUB_PROCESSOR PERFBOOSTMODE -ATTRIB_HIDE`. The powercfg commands above work regardless.
- The change is per power scheme. If the user switches to another scheme (e.g. High performance), that scheme keeps its own value.
- On MSI laptops, MSI Center's User Scenario (Silent / Balanced / Extreme Performance) sets the CPU power limits separately. Turbo off still helps under Extreme Performance, but the two settings stack.
