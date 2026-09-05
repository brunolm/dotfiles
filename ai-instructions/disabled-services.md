# Disabled services

Instructions for an agent setting up a new (or re-installed) Windows machine so its
services match the MSI GE76 tuning from August 2026. Everything here needs an **elevated**
PowerShell. Verify after applying; vendor driver and MSI Center updates can re-enable
their services.

## 1. Vendor services to disable

| Service | Display name | Ships as | Why |
|---|---|---|---|
| `Killer Network Service` | Killer Network Service | Automatic | Killer/Rivet user-mode helpers; the NIC works as a plain adapter on the Microsoft stack without them |
| `Killer Analytics Service` | Killer Analytics Service | Automatic | Telemetry for the above |
| `KillerSmartphoneSleepService` | KillerSmartphoneSleepService | Automatic | Phone-detection gimmick, never used |
| `NahimicService` | Nahimic service | Automatic | MSI's audio enhancement layer; adds a background process and an overlay, no audible benefit here |

**Use the alias for the Killer set**, not `Set-Service`. `B-PC-Set-KillerNetwork off`
(`windows/aliases/pc/killer-network.ps1`) records the previous startup types so `on`
restores them, and it also disables the Killer Control Center startup task. It refuses to
touch `e3k25cx21x64` and `KfeCoSvc`, which are the NIC driver itself; disabling those kills
the adapter.

```powershell
B-PC-Set-KillerNetwork off
Stop-Service NahimicService -Force -ErrorAction SilentlyContinue
Set-Service NahimicService -StartupType Disabled
```

Nahimic also installs four scheduled tasks (`NahimicTask32`, `NahimicTask64`,
`NahimicSvc32Run`, `NahimicSvc64Run`) that start its helper processes at logon. They were
left enabled; disable them too if Nahimic keeps showing up in Task Manager.

## 2. Windows services found disabled (default is Manual)

These are Manual out of the box but are Disabled on the reference machine. There is no
record of when it was done; the reasons below are why it is worth keeping.

| Service | Display name | Why keep disabled |
|---|---|---|
| `WinRM` | Windows Remote Management | Remote management is never used; one less listener |
| `CertPropSvc` | Certificate Propagation | Smart-card only |
| `SCPolicySvc` | Smart Card Removal Policy | Smart-card only |
| `MSiSCSI` | Microsoft iSCSI Initiator Service | No iSCSI targets |

```powershell
foreach ($name in 'WinRM', 'CertPropSvc', 'SCPolicySvc', 'MSiSCSI') {
  Stop-Service $name -Force -ErrorAction SilentlyContinue
  Set-Service $name -StartupType Disabled
}
```

## 3. Disabled by Windows itself, leave alone

Also Disabled on the reference machine, but that is the Windows 11 default, so nothing to
do: `AppVClient`, `CscService`, `DialogBlockingService`, `MsKeyboardFilter`,
`NetTcpPortSharing`, `RemoteAccess`, `RemoteRegistry`, `shpamsvc`, `ssh-agent`,
`tzautoupdate`, `UevAgentService`.

`ssh-agent` stays Disabled on purpose: git and ssh use the keys from `~/.ssh` directly.

## 4. Removed rather than disabled

**Synergy** was uninstalled on 2026-08-11, not just disabled. Its `synergy-daemon.exe`
leaked kernel handles (about 2 per second, 1.4 million open at the time) until the nonpaged
pool reached gigabytes and the machine crawled. Restarting the `Synergy Core Daemon` service
reclaims the pool as a stopgap; the fix was removal. If Synergy is ever reinstalled, check
`(Get-Process synergy-daemon).Handles` after a day of uptime before trusting it.

## 5. Not covered here

Per-game session tweaks (`B-PC-Set-GamingMode` stops `Razer Game Manager Service 3` and
restores it afterwards) are temporary and live in the alias, not in the service config.

## 6. Verify

```powershell
$wanted = 'Killer Network Service', 'Killer Analytics Service', 'KillerSmartphoneSleepService', 'NahimicService', 'WinRM', 'CertPropSvc', 'SCPolicySvc', 'MSiSCSI'
foreach ($name in $wanted) {
  $svc = Get-Service $name -ErrorAction SilentlyContinue
  if (!$svc) { "{0,-30} not installed" -f $name; continue }
  "{0,-30} {1,-10} {2}" -f $name, $svc.StartType, $svc.Status
}
'e3k25cx21x64', 'KfeCoSvc' | ForEach-Object { "{0,-30} {1}  (must NOT be Disabled)" -f $_, (Get-Service $_ -ErrorAction SilentlyContinue).StartType }
```

Expected: every listed service `Disabled` and `Stopped`, the two NIC driver services
anything but Disabled. A service reporting `not installed` is fine; skip it.
