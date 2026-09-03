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

function B-PC-Set-KillerNetwork {
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

  if (!(B-PC-IsElevated)) {
    Write-Error "Needs an elevated shell - run B-PC-Start-Powershell -Elevated first."
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
      Write-Host "Restore with: B-PC-Set-KillerNetwork on" -ForegroundColor Yellow
    }
  }

  PCKiller-DisableApp
  PCKiller-ShowAdapters
  Write-Host "Restore with: B-PC-Set-KillerNetwork on" -ForegroundColor DarkGray
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

