function PC-Disable-Beep() {
  Set-PSReadlineOption -BellStyle None
  # set-service beep -startuptype disabled
}

function PC-Start-Powershell() {
  Start-Process powershell -Verb runAs
}

function PC-IsElevated() {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  return ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function PC-Update-DNS($ips, $id) {
  # Foticlient
  # 172.23.1.1, 172.23.1.10

  if (!$ips) {
    $ips = ("2001:4860:4860:0:0:0:0:8888", "2001:4860:4860:0:0:0:0:8844", "8.8.8.8", "8.8.4.4", "208.67.222.222", "208.67.220.220", "1.1.1.1", "127.0.0.1");
    # $ips = ("127.0.0.1");
  }

  if (!$id) {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses -ne "" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
  else {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.InterfaceIndex -eq $id } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
}

function PC-Network-RestartEthernet() {
  Disable-NetAdapter -Name "Ethernet" -Confirm:$false
  Start-Sleep -Seconds 2
  Enable-NetAdapter -Name "Ethernet" -Confirm:$false
}

function PC-Disable-RealtimeProtection() {
  Set-MpPreference -DisableRealtimeMonitoring $true
}

# NVMe link/idle power settings. Aggressive ASPM L1 plus a short disk idle timeout
# can leave the controller unresponsive on wake; "original" is what the machine shipped with.
function PC-Set-PowerProfile($preset) {
  $presets = @{
    power    = @{ AspmAc = 1; AspmDc = 2; DiskIdleAc = 900; DiskIdleDc = 60 }
    original = @{ AspmAc = 2; AspmDc = 2; DiskIdleAc = 30; DiskIdleDc = 60 }
  }

  if (!$preset -or !$presets.ContainsKey($preset)) {
    Write-Error "Usage: PC-Set-PowerProfile <$($presets.Keys -join '|')>"
    return
  }

  if (!(PC-IsElevated)) {
    Write-Error "Needs an elevated shell - run PC-Start-Powershell first."
    return
  }

  $p = $presets[$preset]

  powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM $p.AspmAc
  powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM $p.AspmDc
  powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE $p.DiskIdleAc
  powercfg /setdcvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE $p.DiskIdleDc
  powercfg /setactive SCHEME_CURRENT

  $aspmNames = @{ 0 = 'Off'; 1 = 'Moderate'; 2 = 'Maximum' }
  Write-Host "Applied '$preset':"
  Write-Host "  ASPM      AC: $($aspmNames[$p.AspmAc])  DC: $($aspmNames[$p.AspmDc])"
  Write-Host "  DiskIdle  AC: $($p.DiskIdleAc)s  DC: $($p.DiskIdleDc)s"
}

# Interactive "free up resources before gaming" sweep. Samples CPU/GPU/IO over a
# short window (cumulative counters need two reads), then lets you pick what dies.
function PC-Set-GamingMode {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet('on', 'off', 'status')]
    [string]$Mode = 'on',
    [int]$MinMemoryMB = 40,
    [double]$MinCpu = 5,
    [double]$MinGpu = 2,
    [double]$MinDiskKB = 100,
    [switch]$Relaunch,
    [switch]$Force
  )

  if ($Mode -eq 'status') {
    PCGaming-Status
    return
  }

  if ($Mode -eq 'off') {
    PCGaming-Restore -Relaunch:$Relaunch -Force:$Force
    return
  }

  # 'Code*' covers both Code and Code - Insiders; 'codex' is listed on its own so it
  # keeps matching the standalone CLI if that pattern is ever narrowed.
  $defaults = @(
    'bun', 'node', 'msedge*', 'chrome', 'claude', 'grok', 'python*',
    'MSI.CentralServer', 'Code*', 'codex'
  )

  # Auto-start services come back if you just kill the pid, so SCM stops them instead.
  $services = @('Razer Game Manager Service 3')

  Write-Host "Sampling processes..." -ForegroundColor DarkGray
  $serviceIds = PCGaming-ServiceProcessIds $services
  $rows = PCGaming-Measure -MinMemoryMB $MinMemoryMB -MinCpu $MinCpu -MinGpu $MinGpu -MinDiskKB $MinDiskKB -SkipIds $serviceIds

  $stoppable = @(PCGaming-RunningServices $services)

  if (!$rows -and !$stoppable) {
    Write-Host "Nothing above the thresholds." -ForegroundColor Green
    return
  }

  PCGaming-ApplyDefaults $rows $defaults

  if (!(PCGaming-Choose -Rows $rows -Defaults $defaults -Action 'continue')) {
    Write-Host "Cancelled." -ForegroundColor DarkGray
    return
  }

  $picked = @($rows | Where-Object { $_.Selected })
  if (!$picked -and !$stoppable) {
    Write-Host "Nothing selected." -ForegroundColor DarkGray
    return
  }

  $totalMB = [math]::Round(($picked | Measure-Object MemMB -Sum).Sum, 0)
  $totalProcs = ($picked | Measure-Object Count -Sum).Sum
  Write-Host ""
  if ($picked) {
    Write-Host "Kill $($picked.Count) app(s) / $totalProcs process(es), freeing ~$totalMB MB:" -ForegroundColor Yellow
    Write-Host "  $(($picked.Name) -join ', ')"
  }
  if ($stoppable) {
    $note = if (PC-IsElevated) { '' } else { ' - will be SKIPPED, needs elevation' }
    Write-Host "Stop $($stoppable.Count) service(s)$($note):" -ForegroundColor Yellow
    Write-Host "  $($stoppable -join ', ')"
  }

  if (!$Force) {
    if ((Read-Host "Confirm? (y/N)") -notmatch '^y') {
      Write-Host "Cancelled." -ForegroundColor DarkGray
      return
    }
  }

  $killed = 0
  foreach ($row in $picked) {
    foreach ($procId in $row.Ids) {
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      if ($?) { $killed++ }
    }
  }

  $stopped = @(PCGaming-StopServices $stoppable)
  PCGaming-SaveState $picked $stopped

  $free = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
  Write-Host "Killed $killed process(es). Free RAM: $free GB" -ForegroundColor Green
  Write-Host "Undo with: PC-Set-GamingMode off" -ForegroundColor DarkGray
}

function PCGaming-RunningServices($names) {
  foreach ($name in $names) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') { $svc.Name }
  }
}

function PCGaming-ServiceProcessIds($names) {
  $ids = @{}
  foreach ($name in $names) {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
    if ($svc.ProcessId) { $ids[[int]$svc.ProcessId] = $true }
  }
  return $ids
}

# Emits the names it actually stopped, so only those get recorded for restore.
function PCGaming-StopServices($names) {
  if (!$names) { return }

  if (!(PC-IsElevated)) {
    Write-Host "Skipped $($names.Count) service(s) - needs an elevated shell (PC-Start-Powershell):" -ForegroundColor Yellow
    Write-Host "  $($names -join ', ')"
    return
  }

  foreach ($name in $names) {
    try {
      Stop-Service -Name $name -Force -ErrorAction Stop
      Write-Host "Stopped service: $name" -ForegroundColor Green
      $name
    }
    catch {
      Write-Host "Failed to stop service '$name': $($_.Exception.Message)" -ForegroundColor Red
    }
  }
}

function PCGaming-StatePath() {
  Join-Path $env:LOCALAPPDATA 'pc-gaming-mode.json'
}

function PCGaming-SaveState($picked, $stopped) {
  $state = [PSCustomObject]@{
    StartedAt = (Get-Date).ToString('o')
    Services  = @($stopped)
    Apps      = @($picked | ForEach-Object {
        [PSCustomObject]@{ Name = $_.Name; Path = $_.Path; Procs = $_.Count; MemMB = $_.MemMB }
      })
  }
  $state | ConvertTo-Json -Depth 4 | Set-Content (PCGaming-StatePath) -Encoding UTF8
}

function PCGaming-Status() {
  $path = PCGaming-StatePath
  if (!(Test-Path $path)) {
    Write-Host "Gaming mode: OFF - nothing recorded." -ForegroundColor Green
    return
  }

  $state = Get-Content $path -Raw | ConvertFrom-Json
  Write-Host "Gaming mode: ON since $($state.StartedAt)" -ForegroundColor Yellow

  if ($state.Services) {
    Write-Host "  Services stopped (restorable):" -ForegroundColor Cyan
    foreach ($name in $state.Services) {
      $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
      Write-Host "    $name  [now: $(if ($svc) { $svc.Status } else { 'missing' })]"
    }
  }

  if ($state.Apps) {
    Write-Host "  Apps killed (relaunch is best-effort):" -ForegroundColor Cyan
    foreach ($app in $state.Apps) {
      $running = @(Get-Process -Name $app.Name -ErrorAction SilentlyContinue).Count
      Write-Host ("    {0,-24} {1,3} procs, {2,5} MB  [now: {3} running]" -f $app.Name, $app.Procs, $app.MemMB, $running)
    }
  }
}

# Services restore cleanly; killed processes do not - relaunching only reopens the exe,
# without the windows, tabs, working directory or arguments it had before.
function PCGaming-Restore {
  param([switch]$Relaunch, [switch]$Force)

  $path = PCGaming-StatePath
  if (!(Test-Path $path)) {
    Write-Host "No saved state - nothing to restore." -ForegroundColor DarkGray
    return
  }

  $state = Get-Content $path -Raw | ConvertFrom-Json
  $services = @($state.Services)
  $apps = @($state.Apps)

  if ($services) {
    if (!(PC-IsElevated)) {
      Write-Host "Cannot restart services - needs an elevated shell (PC-Start-Powershell):" -ForegroundColor Yellow
      Write-Host "  $($services -join ', ')"
    }
    else {
      foreach ($name in $services) {
        try {
          Start-Service -Name $name -ErrorAction Stop
          Write-Host "Started service: $name" -ForegroundColor Green
        }
        catch {
          Write-Host "Failed to start service '$name': $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }
  }

  if ($apps -and !$Relaunch) {
    Write-Host ""
    Write-Host "These apps were killed - reopen the ones you want, or re-run with -Relaunch:" -ForegroundColor Cyan
    Write-Host "  $(($apps.Name) -join ', ')"
  }

  if ($apps -and $Relaunch) {
    PCGaming-RelaunchApps $apps -Force:$Force
  }

  Remove-Item $path -Force -ErrorAction SilentlyContinue
  Write-Host "Gaming mode off." -ForegroundColor Green
}

# Nothing is preselected here - relaunching loses tabs, windows and arguments, so
# reopening an app has to be a deliberate pick rather than the default.
function PCGaming-RelaunchApps {
  param($apps, [switch]$Force)

  $skipped = @($apps | Where-Object { !$_.Path -or !(Test-Path $_.Path) })
  if ($skipped) {
    Write-Host "No usable path, cannot relaunch: $(($skipped.Name) -join ', ')" -ForegroundColor DarkGray
  }

  $running = @($apps | Where-Object { Get-Process -Name $_.Name -ErrorAction SilentlyContinue })
  if ($running) {
    Write-Host "Already running, skipping: $(($running.Name) -join ', ')" -ForegroundColor DarkGray
  }

  $rows = @($apps |
    Where-Object { $_.Path -and (Test-Path $_.Path) } |
    Where-Object { !(Get-Process -Name $_.Name -ErrorAction SilentlyContinue) } |
    ForEach-Object {
      [PSCustomObject]@{
        Selected = $false
        Name     = $_.Name
        Count    = $_.Procs
        MemMB    = $_.MemMB
        Path     = $_.Path
      }
    })

  if (!$rows) {
    Write-Host "Nothing left to relaunch." -ForegroundColor DarkGray
    return
  }

  if (!(PCGaming-Choose -Rows $rows -Defaults @() -Columns $script:PCGamingRestoreColumns -Action 'relaunch')) {
    Write-Host "Relaunch cancelled." -ForegroundColor DarkGray
    return
  }

  $picked = @($rows | Where-Object { $_.Selected })
  if (!$picked) {
    Write-Host "Nothing selected to relaunch." -ForegroundColor DarkGray
    return
  }

  if (!$Force) {
    Write-Host ""
    Write-Host "Relaunch $($picked.Count) app(s): $(($picked.Name) -join ', ')" -ForegroundColor Yellow
    if ((Read-Host "Confirm? (y/N)") -notmatch '^y') {
      Write-Host "Relaunch cancelled." -ForegroundColor DarkGray
      return
    }
  }

  foreach ($app in $picked) {
    try {
      Start-Process -FilePath $app.Path -ErrorAction Stop
      Write-Host "Relaunched: $($app.Name)" -ForegroundColor Green
    }
    catch {
      Write-Host "Failed to relaunch '$($app.Name)': $($_.Exception.Message)" -ForegroundColor Red
    }
  }
}

function PCGaming-ApplyDefaults($rows, $defaults) {
  foreach ($row in $rows) {
    $row.Selected = [bool]($defaults | Where-Object { $row.Name -like $_ })
  }
}

function PCGaming-Measure {
  param($MinMemoryMB, $MinCpu, $MinGpu, $MinDiskKB, $SkipIds = @{})

  $protected = PCGaming-ProtectedNames
  $ancestors = PCGaming-AncestorIds
  $cores = [Environment]::ProcessorCount

  $cpuStart = @{}
  foreach ($p in Get-Process) {
    if ($null -ne $p.CPU) { $cpuStart[$p.Id] = $p.CPU }
  }
  $ioStart = PCGaming-IoBytes
  $clock = [Diagnostics.Stopwatch]::StartNew()

  # Doubles as the sampling window for the CPU/IO deltas taken after it returns.
  $gpu = PCGaming-GpuByProcess

  $clock.Stop()
  $elapsed = [math]::Max($clock.Elapsed.TotalSeconds, 0.5)
  $ioEnd = PCGaming-IoBytes

  $rows = foreach ($p in Get-Process) {
    if ($protected -contains $p.ProcessName) { continue }
    if ($ancestors.ContainsKey($p.Id)) { continue }
    if ($SkipIds.ContainsKey($p.Id)) { continue }

    $cpu = 0.0
    if ($cpuStart.ContainsKey($p.Id) -and $null -ne $p.CPU) {
      $cpu = ($p.CPU - $cpuStart[$p.Id]) / $elapsed / $cores * 100
    }

    $io = 0.0
    if ($ioStart.ContainsKey($p.Id) -and $ioEnd.ContainsKey($p.Id)) {
      $io = ($ioEnd[$p.Id] - $ioStart[$p.Id]) / $elapsed / 1KB
    }

    # Protected processes throw on .Path; a missing path just means no relaunch offer.
    $path = try { $p.Path } catch { $null }

    [PSCustomObject]@{
      Id    = $p.Id
      Name  = $p.ProcessName
      Path  = $path
      MemMB = $p.WorkingSet64 / 1MB
      Cpu   = [math]::Max($cpu, 0)
      Gpu   = [double]$gpu[$p.Id]
      IoKB  = [math]::Max($io, 0)
    }
  }

  $grouped = $rows | Group-Object Name | ForEach-Object {
    [PSCustomObject]@{
      Selected = $false
      Name     = $_.Name
      Count    = $_.Count
      Ids      = @($_.Group.Id)
      Path     = @($_.Group.Path | Where-Object { $_ })[0]
      MemMB    = [math]::Round(($_.Group | Measure-Object MemMB -Sum).Sum, 0)
      Cpu      = [math]::Round(($_.Group | Measure-Object Cpu -Sum).Sum, 1)
      Gpu      = [math]::Round(($_.Group | Measure-Object Gpu -Sum).Sum, 1)
      IoKB     = [math]::Round(($_.Group | Measure-Object IoKB -Sum).Sum, 0)
    }
  }

  @($grouped |
    Where-Object { $_.MemMB -ge $MinMemoryMB -or $_.Cpu -ge $MinCpu -or $_.Gpu -ge $MinGpu -or $_.IoKB -ge $MinDiskKB } |
    Sort-Object MemMB -Descending)
}

$script:PCGamingKillColumns = @(
  @{ Header = 'Process'; Property = 'Name'; Width = -28 }
  @{ Header = 'Procs'; Property = 'Count'; Width = 5 }
  @{ Header = 'Mem MB'; Property = 'MemMB'; Width = 8 }
  @{ Header = 'CPU %'; Property = 'Cpu'; Width = 7 }
  @{ Header = 'GPU %'; Property = 'Gpu'; Width = 7 }
  @{ Header = 'IO KB/s'; Property = 'IoKB'; Width = 9 }
)

$script:PCGamingRestoreColumns = @(
  @{ Header = 'Process'; Property = 'Name'; Width = -28 }
  @{ Header = 'Procs'; Property = 'Count'; Width = 5 }
  @{ Header = 'Was MB'; Property = 'MemMB'; Width = 8 }
  @{ Header = 'Path'; Property = 'Path'; Width = -60 }
)

function PCGaming-Choose {
  param($Rows, $Defaults, $Columns = $script:PCGamingKillColumns, [string]$Action = 'continue')

  $slots = @('{0,3}', '{1,-3}')
  $index = 2
  foreach ($col in $Columns) { $slots += "{$index,$($col.Width)}"; $index++ }
  $fmt = $slots -join '  '

  $headers = @('#', 'Sel') + @($Columns.Header)

  while ($true) {
    Write-Host ""
    Write-Host ($fmt -f $headers) -ForegroundColor Cyan
    for ($i = 0; $i -lt $Rows.Count; $i++) {
      $row = $Rows[$i]
      $mark = if ($row.Selected) { '[x]' } else { '[ ]' }
      $color = if ($row.Selected) { 'Yellow' } else { 'Gray' }
      $values = @(($i + 1), $mark) + @($Columns | ForEach-Object { $row."$($_.Property)" })
      Write-Host ($fmt -f $values) -ForegroundColor $color
    }

    $sel = @($Rows | Where-Object { $_.Selected })
    $selMB = [math]::Round(($sel | Measure-Object MemMB -Sum).Sum, 0)
    Write-Host ""
    Write-Host "Selected: $($sel.Count) app(s), ~$selMB MB" -ForegroundColor DarkGray
    Write-Host "Toggle numbers (1,3,5-7) | a=all  n=none  d=defaults | Enter=$Action  q=quit" -ForegroundColor DarkGray

    $answer = (Read-Host ">").Trim()

    if ($answer -eq '') { return $true }
    if ($answer -eq 'q') { return $false }
    if ($answer -eq 'a') { $Rows | ForEach-Object { $_.Selected = $true }; continue }
    if ($answer -eq 'n') { $Rows | ForEach-Object { $_.Selected = $false }; continue }
    if ($answer -eq 'd') { PCGaming-ApplyDefaults $Rows $Defaults; continue }

    foreach ($token in ($answer -split '[,\s]+' | Where-Object { $_ })) {
      if ($token -match '^(\d+)-(\d+)$') {
        [int]$from, [int]$to = $Matches[1], $Matches[2]
      }
      elseif ($token -match '^\d+$') {
        [int]$from = [int]$token; $to = $from
      }
      else { continue }

      for ($n = $from; $n -le $to; $n++) {
        if ($n -ge 1 -and $n -le $Rows.Count) {
          $Rows[$n - 1].Selected = !$Rows[$n - 1].Selected
        }
      }
    }
  }
}

# GPU counter instances are named pid_<id>_luid_..._engtype_<engine>; Task Manager
# approximates per-process load the same way, by summing every engine for that pid.
function PCGaming-GpuByProcess {
  $byProcess = @{}
  try {
    $sets = Get-Counter '\GPU Engine(*)\Utilization Percentage' -SampleInterval 1 -MaxSamples 2 -ErrorAction Stop
    foreach ($s in $sets[-1].CounterSamples) {
      if ($s.InstanceName -match '^pid_(\d+)_') {
        $byProcess[[int]$Matches[1]] += $s.CookedValue
      }
    }
  }
  catch {
    Start-Sleep -Seconds 2
  }
  return $byProcess
}

function PCGaming-IoBytes {
  $bytes = @{}
  foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, ReadTransferCount, WriteTransferCount) {
    $bytes[[int]$p.ProcessId] = [double]$p.ReadTransferCount + [double]$p.WriteTransferCount
  }
  return $bytes
}

# Killing these either bugchecks the box, tears down the desktop, or kills the GPU
# and audio stack the game needs - they stay out of the picker entirely.
function PCGaming-ProtectedNames {
  @(
    'Idle', 'System', 'Registry', 'Secure System', 'Memory Compression', 'MemCompression',
    'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'LsaIso', 'fontdrvhost',
    'svchost', 'dwm', 'explorer', 'audiodg', 'ctfmon', 'sihost', 'taskhostw', 'dllhost',
    'MsMpEng', 'SecurityHealthService', 'SecurityHealthSystray', 'WUDFHost',
    'nvcontainer', 'NVDisplay.Container', 'NVIDIA Share', 'nvsphelper64',
    'ShellExperienceHost', 'StartMenuExperienceHost', 'SearchHost', 'TextInputHost',
    'ApplicationFrameHost', 'RuntimeBroker', 'conhost'
  )
}

# The shell running this command is somewhere up the parent chain; killing a group
# it belongs to (pwsh, WindowsTerminal) would take the session down mid-sweep.
function PCGaming-AncestorIds {
  $parents = @{}
  foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId) {
    $parents[[int]$p.ProcessId] = [int]$p.ParentProcessId
  }

  $ids = @{}
  $current = $PID
  while ($current -and !$ids.ContainsKey($current)) {
    $ids[$current] = $true
    $current = $parents[$current]
  }
  return $ids
}

# Killer/Rivet user-mode services only. These sit beside the network stack rather
# than in it - no Killer NDIS filter is bound to any adapter, so disabling them
# leaves the NICs working as ordinary adapters on the Microsoft stack.
$script:PCKillerServices = @(
  'Killer Network Service'
  'Killer Analytics Service'
  'KillerSmartphoneSleepService'
)

# e3k25cx21x64 is the NIC driver itself and KfeCoSvc the helper it starts on demand;
# disabling either kills the adapter. Guarded so an edit to the list above can't.
$script:PCKillerProtected = @('e3k25cx21x64', 'KfeCoSvc')

# Fallback for 'on' when no saved state exists - the factory values these shipped with.
$script:PCKillerDefaults = @(
  @{ Name = 'Killer Network Service'; Startup = 'Automatic'; Running = $true }
  @{ Name = 'Killer Analytics Service'; Startup = 'Automatic'; Running = $true }
  @{ Name = 'KillerSmartphoneSleepService'; Startup = 'Automatic'; Running = $true }
)

# The Control Center UI is a Store app, so it survives a process kill via its startup
# task. State 2 is enabled, 1 is disabled; the key lives in HKCU (no elevation needed).
$script:PCKillerApp = @{
  Process       = 'KillerIntelligenceCenter'
  PackageFamily = 'RivetNetworks.KillerControlCenter_rh07ty8m5nkag'
  Task          = 'KillerControlCenterTask'
  DefaultState  = 2
}

function PC-Set-KillerNetwork {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet('on', 'off', 'status')]
    [string]$Mode = 'status',
    [switch]$Force
  )

  if ($Mode -eq 'status') {
    PCKiller-Status
    return
  }

  $conflict = @($script:PCKillerServices | Where-Object { $script:PCKillerProtected -contains $_ })
  if ($conflict) {
    Write-Error "Refusing to touch protected service(s): $($conflict -join ', ')"
    return
  }

  if (!(PC-IsElevated)) {
    Write-Error "Needs an elevated shell - run PC-Start-Powershell first."
    return
  }

  if ($Mode -eq 'off') {
    PCKiller-Disable -Force:$Force
    return
  }

  PCKiller-Restore -Force:$Force
}

function PCKiller-StatePath() {
  Join-Path $env:LOCALAPPDATA 'pc-killer-network.json'
}

# Win32_Service is used for reads because StartMode/DelayedAutoStart are available on
# both Windows PowerShell and pwsh, unlike Get-Service's StartType. Kernel drivers
# (e3k25cx21x64, KfeCoSvc) are not in that class, so fall back to Win32_SystemDriver.
function PCKiller-Read($name) {
  $svc = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
  if (!$svc) { $svc = Get-CimInstance Win32_SystemDriver -Filter "Name='$name'" -ErrorAction SilentlyContinue }
  if (!$svc) { return $null }

  $startup = switch ($svc.StartMode) {
    'Auto' { if ($svc.DelayedAutoStart) { 'AutomaticDelayedStart' } else { 'Automatic' } }
    'Disabled' { 'Disabled' }
    'Manual' { 'Manual' }
    default { $svc.StartMode }
  }

  [PSCustomObject]@{
    Name    = $svc.Name
    Startup = $startup
    Running = ($svc.State -eq 'Running')
    State   = $svc.State
  }
}

function PCKiller-AppTaskKey() {
  $app = $script:PCKillerApp
  "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($app.PackageFamily)\$($app.Task)"
}

function PCKiller-ReadAppTask() {
  $key = PCKiller-AppTaskKey
  if (!(Test-Path $key)) { return $null }
  (Get-ItemProperty $key -Name State -ErrorAction SilentlyContinue).State
}

function PCKiller-SetAppTask($state) {
  $key = PCKiller-AppTaskKey
  if (!(Test-Path $key)) { return $false }
  Set-ItemProperty -Path $key -Name State -Value ([int]$state) -Type DWord -ErrorAction Stop
  return $true
}

function PCKiller-SetStartup($name, $startup) {
  try {
    Set-Service -Name $name -StartupType $startup -ErrorAction Stop
  }
  catch {
    # AutomaticDelayedStart is pwsh-only; Automatic is the safe equivalent on 5.1.
    if ($startup -ne 'AutomaticDelayedStart') { throw }
    Set-Service -Name $name -StartupType Automatic -ErrorAction Stop
  }
}

function PCKiller-Status() {
  Write-Host "Killer user-mode services:" -ForegroundColor Cyan
  foreach ($name in $script:PCKillerServices) {
    $svc = PCKiller-Read $name
    if (!$svc) {
      Write-Host ("  {0,-36} (not installed)" -f $name) -ForegroundColor DarkGray
      continue
    }
    $color = if ($svc.Startup -eq 'Disabled') { 'Yellow' } else { 'Gray' }
    Write-Host ("  {0,-36} {1,-22} {2}" -f $svc.Name, $svc.Startup, $svc.State) -ForegroundColor $color
  }

  Write-Host "Never touched (NIC driver + helper):" -ForegroundColor Cyan
  foreach ($name in $script:PCKillerProtected) {
    $svc = PCKiller-Read $name
    if ($svc) { Write-Host ("  {0,-36} {1,-22} {2}" -f $svc.Name, $svc.Startup, $svc.State) -ForegroundColor DarkGray }
  }

  $app = $script:PCKillerApp
  $task = PCKiller-ReadAppTask
  $running = @(Get-Process -Name $app.Process -ErrorAction SilentlyContinue)
  $taskText = switch ($task) {
    $null { 'no startup task' }
    2 { 'autostart enabled' }
    default { "autostart disabled (state $task)" }
  }
  $mb = if ($running) { "$([math]::Round(($running | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 0)) MB" } else { 'not running' }
  Write-Host "Control Center app:" -ForegroundColor Cyan
  Write-Host ("  {0,-36} {1,-22} {2}" -f $app.Process, $taskText, $mb)

  $statePath = PCKiller-StatePath
  Write-Host "Saved state: $(if (Test-Path $statePath) { $statePath } else { '(none)' })" -ForegroundColor DarkGray

  PCKiller-ShowAdapters
}

function PCKiller-ShowAdapters() {
  Write-Host "Network adapters:" -ForegroundColor Cyan
  foreach ($a in Get-NetAdapter -ErrorAction SilentlyContinue | Sort-Object Name) {
    $color = if ($a.Status -eq 'Up') { 'Green' } else { 'DarkGray' }
    Write-Host ("  {0,-30} {1,-14} {2}" -f $a.Name, $a.Status, $a.LinkSpeed) -ForegroundColor $color
  }
}

function PCKiller-Disable {
  param([switch]$Force)

  $current = @($script:PCKillerServices | ForEach-Object { PCKiller-Read $_ } | Where-Object { $_ })
  if (!$current) {
    Write-Host "No Killer services found - nothing to do." -ForegroundColor DarkGray
    return
  }

  $todo = @($current | Where-Object { $_.Startup -ne 'Disabled' -or $_.Running })
  if (!$todo) {
    Write-Host "Already disabled." -ForegroundColor Green
    return
  }

  if (!$Force) {
    Write-Host "Disable $($todo.Count) Killer service(s):" -ForegroundColor Yellow
    $todo | ForEach-Object { Write-Host "  $($_.Name)  [$($_.Startup), $($_.State)]" }
    Write-Host "The NIC driver (e3k25cx21x64) and KfeCoSvc are not touched." -ForegroundColor DarkGray
    if ((Read-Host "Confirm? (y/N)") -notmatch '^y') {
      Write-Host "Cancelled." -ForegroundColor DarkGray
      return
    }
  }

  # Written before any change, and never overwritten, so a second 'off' cannot
  # record the already-disabled state as the thing to restore.
  $statePath = PCKiller-StatePath
  if (!(Test-Path $statePath)) {
    [PSCustomObject]@{
      Services = @($current)
      AppTask  = PCKiller-ReadAppTask
    } | ConvertTo-Json -Depth 5 | Set-Content $statePath -Encoding UTF8
    Write-Host "Saved original state -> $statePath" -ForegroundColor DarkGray
  }
  else {
    Write-Host "Keeping existing saved state (already recorded)." -ForegroundColor DarkGray
  }

  foreach ($svc in $todo) {
    try {
      if ($svc.Running) { Stop-Service -Name $svc.Name -Force -ErrorAction Stop }
      PCKiller-SetStartup $svc.Name 'Disabled'
      Write-Host "Disabled: $($svc.Name)" -ForegroundColor Green
    }
    catch {
      Write-Host "Failed on '$($svc.Name)': $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "Restore with: PC-Set-KillerNetwork on" -ForegroundColor Yellow
    }
  }

  PCKiller-DisableApp
  PCKiller-ShowAdapters
  Write-Host "Restore with: PC-Set-KillerNetwork on" -ForegroundColor DarkGray
}

function PCKiller-DisableApp() {
  $app = $script:PCKillerApp

  if ($null -ne (PCKiller-ReadAppTask)) {
    try {
      PCKiller-SetAppTask 1 | Out-Null
      Write-Host "Autostart disabled: $($app.Process)" -ForegroundColor Green
    }
    catch {
      Write-Host "Failed to disable autostart for '$($app.Process)': $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  $running = @(Get-Process -Name $app.Process -ErrorAction SilentlyContinue)
  if (!$running) { return }

  $mb = [math]::Round(($running | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 0)
  $running | Stop-Process -Force -ErrorAction SilentlyContinue
  Write-Host "Killed: $($app.Process) (~$mb MB)" -ForegroundColor Green
}

function PCKiller-Restore {
  param([switch]$Force)

  $statePath = PCKiller-StatePath
  $state = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json } else { $null }

  $saved = @($state.Services)
  $appTask = $state.AppTask

  if (!$saved) {
    Write-Host "No saved state - restoring known factory defaults." -ForegroundColor Yellow
    $saved = @($script:PCKillerDefaults | ForEach-Object { [PSCustomObject]$_ })
    $appTask = $script:PCKillerApp.DefaultState
  }

  if (!$Force) {
    Write-Host "Restore $($saved.Count) Killer service(s):" -ForegroundColor Yellow
    $saved | ForEach-Object { Write-Host "  $($_.Name) -> $($_.Startup)$(if ($_.Running) { ', started' })" }
    if ($null -ne $appTask) {
      Write-Host "  $($script:PCKillerApp.Process) autostart -> $(if ($appTask -eq 2) { 'enabled' } else { "state $appTask" })"
    }
    if ((Read-Host "Confirm? (y/N)") -notmatch '^y') {
      Write-Host "Cancelled." -ForegroundColor DarkGray
      return
    }
  }

  $failed = $false
  foreach ($svc in $saved) {
    if ($script:PCKillerProtected -contains $svc.Name) { continue }
    try {
      # Startup type first - a Disabled service cannot be started.
      PCKiller-SetStartup $svc.Name $svc.Startup
      if ($svc.Running) { Start-Service -Name $svc.Name -ErrorAction Stop }
      Write-Host "Restored: $($svc.Name) -> $($svc.Startup)$(if ($svc.Running) { ', running' })" -ForegroundColor Green
    }
    catch {
      $failed = $true
      Write-Host "Failed on '$($svc.Name)': $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  if ($null -ne $appTask) {
    try {
      if (PCKiller-SetAppTask $appTask) {
        Write-Host "Restored: $($script:PCKillerApp.Process) autostart -> $(if ($appTask -eq 2) { 'enabled' } else { "state $appTask" })" -ForegroundColor Green
        Write-Host "  (the app itself starts at next sign-in)" -ForegroundColor DarkGray
      }
    }
    catch {
      $failed = $true
      Write-Host "Failed to restore autostart: $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  if (!$failed) { Remove-Item $statePath -Force -ErrorAction SilentlyContinue }
  else { Write-Host "Keeping saved state at $statePath for a retry." -ForegroundColor Yellow }

  PCKiller-ShowAdapters
}

function psl() {
  $saveY = [console]::CursorTop
  $saveX = [console]::CursorLeft

  while ($true) {
    Get-Process | Sort-Object -Descending CPU | Select-Object -First 30;
    Start-Sleep -Seconds 2;
    [console]::setcursorposition($saveX, $saveY + 3)
  }
}

function which($p) {
  (Get-Command $p).Definition
}


PC-Disable-Beep
