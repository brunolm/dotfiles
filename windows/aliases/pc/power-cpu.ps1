# CPU frequency/boost policy. The CPU runs in HWP autonomous mode, so Windows only
# steers it through these knobs; the perf increase/decrease thresholds have no effect.
#
# Class 0 = E-cores, class 1 = P-cores. The class-1 overrides win for the P-cores, so a
# cap set only on the base setting never reaches the cores that produce the heat.
#
# The power-mode overlay (the Settings > Power slider) sits on top of the scheme and
# lowers EPP on "Best performance"; it is global, not per scheme.
#
# "default" is the machine's 2026-09-03 baseline (stock Windows plus the 95% E-core cap)
# with turbo set to Efficient Enabled and the power mode moved to Balanced. "balanced" is
# the 95% cap on both core classes with turbo off, "cool" trades peak speed for
# temperature, "freezing" is cool with the clocks capped at 40%, "perf" is default on the
# Best performance power mode with a lower energy preference, "hell" is everything on.
# "windows-balanced" is Microsoft's shipped Balanced scheme, read from the registry's
# DefaultPowerSchemeValues; MSI's provisioning raises the AC energy preference to 45.
function B-PC-Set-CpuProfile {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet('freezing', 'cool', 'balanced', 'default', 'perf', 'hell', 'windows-balanced', 'status')]
    [string]$Preset = 'status',
    [switch]$AllSchemes
  )

  $settings = PCCpu-Settings
  if ($Preset -eq 'status') {
    PCPower-Status $settings (PCCpu-PowerModeRow)
    return
  }

  $values = [ordered]@{} + (PCCpu-Presets)[$Preset]
  $powerMode = $values['PowerMode']
  $values.Remove('PowerMode')

  $applied = PCPower-ApplyPreset $Preset $settings $values $AllSchemes
  if (!$applied) { return }

  powercfg /overlaysetactive (PCCpu-PowerModes)[$powerMode] | Out-Null
  PCPower-Status $settings (PCCpu-PowerModeRow)
}

# Prints every preset side by side. A cell shows one value when AC and DC agree,
# otherwise "AC / DC".
function B-PC-Show-CpuProfiles {
  $settings = PCCpu-Settings
  $presets = PCCpu-Presets

  $rows = foreach ($name in $settings.Keys) {
    $row = [ordered]@{ Setting = $settings[$name].Label }
    foreach ($preset in $presets.Keys) {
      $pair = $presets[$preset][$name]
      $ac = PCPower-Format $settings[$name] $pair[0]
      $dc = PCPower-Format $settings[$name] $pair[1]
      $row[$preset] = if ($ac -eq $dc) { $ac } else { "$ac / $dc" }
    }
    [pscustomobject]$row
  }

  $modeRow = [ordered]@{ Setting = 'Power mode (overlay)' }
  foreach ($preset in $presets.Keys) { $modeRow[$preset] = $presets[$preset].PowerMode }

  @($rows) + [pscustomobject]$modeRow | Format-Table -AutoSize
}

# All under SUB_PROCESSOR. EPP: higher = favor efficiency (0-100). Latency hint: the clock
# bump Windows applies on user input.
function PCCpu-Settings() {
  $cpu = '54533251-82be-4824-96c1-47b60b740d00'

  return [ordered]@{
    BoostMode     = @{ Sub = $cpu; Guid = 'be337238-0d82-4146-a960-4f3749d470c7'; Label = 'Turbo boost mode'; Unit = 'boost' }
    Epp           = @{ Sub = $cpu; Guid = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'; Label = 'Energy preference (E-cores)'; Unit = '%' }
    EppPCore      = @{ Sub = $cpu; Guid = '36687f9e-e3a5-4dbf-b1dc-15eb381c6864'; Label = 'Energy preference (P-cores)'; Unit = '%' }
    MaxState      = @{ Sub = $cpu; Guid = 'bc5038f7-23e0-4960-96da-33abaf5935ec'; Label = 'Max processor state (E-cores)'; Unit = '%' }
    MaxStatePCore = @{ Sub = $cpu; Guid = 'bc5038f7-23e0-4960-96da-33abaf5935ed'; Label = 'Max processor state (P-cores)'; Unit = '%' }
    SchedPolicy   = @{ Sub = $cpu; Guid = '93b8b6dc-0698-4d1c-9ee4-0644e900c85d'; Label = 'Thread scheduling'; Unit = 'sched' }
    CoolingPolicy = @{ Sub = $cpu; Guid = '94d3a615-a899-4ac5-ae2b-e4d8f634367f'; Label = 'Cooling policy'; Unit = 'cooling' }
    LatencyHint   = @{ Sub = $cpu; Guid = '619b7505-003b-4e82-b7a6-4dd29c300971'; Label = 'Latency hint performance'; Unit = '%' }
  }
}

# Each entry is @(AC, DC), except PowerMode which is a key of PCCpu-PowerModes.
function PCCpu-Presets() {
  return [ordered]@{
    'freezing' = [ordered]@{
      BoostMode     = @(0, 0)
      Epp           = @(70, 80)
      EppPCore      = @(70, 80)
      MaxState      = @(40, 40)
      MaxStatePCore = @(40, 40)
      SchedPolicy   = @(4, 4)
      CoolingPolicy = @(0, 0)
      LatencyHint   = @(50, 50)
      PowerMode     = 'best-efficiency'
    }
    'cool'     = [ordered]@{
      BoostMode     = @(0, 0)
      Epp           = @(60, 70)
      EppPCore      = @(60, 70)
      MaxState      = @(70, 70)
      MaxStatePCore = @(70, 70)
      SchedPolicy   = @(4, 4)
      CoolingPolicy = @(0, 0)
      LatencyHint   = @(50, 50)
      PowerMode     = 'best-efficiency'
    }
    'balanced' = [ordered]@{
      BoostMode     = @(0, 0)
      Epp           = @(50, 60)
      EppPCore      = @(50, 60)
      MaxState      = @(95, 95)
      MaxStatePCore = @(95, 95)
      SchedPolicy   = @(5, 5)
      CoolingPolicy = @(1, 0)
      LatencyHint   = @(99, 99)
      PowerMode     = 'balanced'
    }
    'default'  = [ordered]@{
      BoostMode     = @(3, 3)
      Epp           = @(45, 50)
      EppPCore      = @(45, 50)
      MaxState      = @(95, 95)
      MaxStatePCore = @(95, 95)
      SchedPolicy   = @(5, 5)
      CoolingPolicy = @(1, 0)
      LatencyHint   = @(99, 99)
      PowerMode     = 'balanced'
    }
    'perf'     = [ordered]@{
      BoostMode     = @(3, 3)
      Epp           = @(25, 25)
      EppPCore      = @(25, 25)
      MaxState      = @(95, 95)
      MaxStatePCore = @(95, 95)
      SchedPolicy   = @(5, 5)
      CoolingPolicy = @(1, 1)
      LatencyHint   = @(99, 99)
      PowerMode     = 'best-performance'
    }
    'hell'     = [ordered]@{
      BoostMode     = @(2, 2)
      Epp           = @(10, 10)
      EppPCore      = @(10, 10)
      MaxState      = @(100, 95)
      MaxStatePCore = @(100, 100)
      SchedPolicy   = @(5, 5)
      CoolingPolicy = @(1, 1)
      LatencyHint   = @(99, 99)
      PowerMode     = 'best-performance'
    }
    'windows-balanced' = [ordered]@{
      BoostMode     = @(2, 2)
      Epp           = @(33, 50)
      EppPCore      = @(33, 50)
      MaxState      = @(100, 100)
      MaxStatePCore = @(100, 100)
      SchedPolicy   = @(5, 5)
      CoolingPolicy = @(1, 0)
      LatencyHint   = @(99, 99)
      PowerMode     = 'balanced'
    }
  }
}

function PCCpu-PowerModes() {
  return [ordered]@{
    'best-efficiency'  = '961cc777-2547-4f9d-8174-7d86181b8a7a'
    'balanced'         = '00000000-0000-0000-0000-000000000000'
    'best-performance' = 'ded574b5-45a0-4f42-8737-46345c09c238'
  }
}

function PCCpu-PowerModeRow() {
  $active = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes').ActiveOverlayAcPowerScheme
  $name = (PCCpu-PowerModes).GetEnumerator() | Where-Object { $_.Value -eq $active } | ForEach-Object { $_.Key }

  return [pscustomobject]@{ Setting = 'Power mode (overlay)'; AC = $(if ($name) { $name } else { $active }); DC = ''; Source = 'global' }
}
