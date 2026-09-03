function PCPower-ApplyPreset($preset, $settings, $values, $allSchemes) {
  if (!(B-PC-IsElevated)) {
    Write-Error "Needs an elevated shell - run B-PC-Start-Powershell -Elevated first."
    return $false
  }

  $schemes = if ($allSchemes) { PCPower-SchemeGuids } else { @(PCPower-ActiveScheme) }
  if (!$schemes) {
    Write-Error "Could not resolve a power scheme GUID from powercfg."
    return $false
  }

  $failed = 0
  foreach ($scheme in $schemes) {
    $failed += PCPower-Apply $scheme $settings $values
  }

  # powercfg only writes the registry; the scheme has to be re-applied to take effect.
  powercfg /setactive (PCPower-ActiveScheme) | Out-Null

  $scope = if ($allSchemes) { "$($schemes.Count) scheme(s)" } else { 'active scheme' }
  if ($failed) {
    Write-Warning "Applied '$preset' to $scope with $failed setting(s) rejected by powercfg."
  }
  else {
    Write-Host "Applied '$preset' to $scope." -ForegroundColor Green
  }

  return $true
}

function PCPower-Apply($scheme, $settings, $values) {
  $failed = 0

  foreach ($name in $values.Keys) {
    $setting = $settings[$name]
    $pair = $values[$name]

    powercfg /setacvalueindex $scheme $setting.Sub $setting.Guid $pair[0] | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed++; Write-Warning "AC $($setting.Label) rejected." }

    powercfg /setdcvalueindex $scheme $setting.Sub $setting.Guid $pair[1] | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed++; Write-Warning "DC $($setting.Label) rejected." }
  }

  return $failed
}

function PCPower-Status($settings, $extraRows) {
  $scheme = PCPower-ActiveScheme
  if (!$scheme) {
    Write-Error "Could not resolve the active power scheme."
    return
  }

  $rows = foreach ($name in $settings.Keys) {
    $setting = $settings[$name]
    $current = PCPower-CurrentValue $scheme $setting

    [pscustomobject]@{
      Setting = $setting.Label
      AC      = PCPower-Format $setting $current.Ac
      DC      = PCPower-Format $setting $current.Dc
      Source  = if ($current) { $current.Source } else { 'unset' }
    }
  }

  Write-Host ""
  Write-Host "Active scheme: $scheme" -ForegroundColor DarkGray
  @($rows) + @($extraRows) | Format-Table -AutoSize
  Write-Host "Source 'scheme' = set by a preset, 'default' = still Windows stock." -ForegroundColor DarkGray
}

# powercfg /qh reports the effective value and, unlike /query, includes hidden settings.
# The per-scheme registry key only exists once something wrote the value, which is what
# separates a preset-applied setting from Windows stock.
function PCPower-CurrentValue($scheme, $setting) {
  $query = (powercfg /qh $scheme $setting.Sub $setting.Guid) -join [Environment]::NewLine
  if ($query -notmatch 'Current AC Power Setting Index: 0x([0-9a-f]+)') { return $null }
  $ac = [Convert]::ToInt32($Matches[1], 16)
  if ($query -notmatch 'Current DC Power Setting Index: 0x([0-9a-f]+)') { return $null }
  $dc = [Convert]::ToInt32($Matches[1], 16)

  $override = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$scheme\$($setting.Sub)\$($setting.Guid)"
  $source = if (Test-Path $override) { 'scheme' } else { 'default' }

  return [pscustomobject]@{ Ac = $ac; Dc = $dc; Source = $source }
}

function PCPower-SchemeGuids() {
  return powercfg /list | ForEach-Object {
    if ($_ -match 'GUID:\s*([0-9a-f-]{36})') { $Matches[1] }
  }
}

function PCPower-ActiveScheme() {
  if ((powercfg /getactivescheme) -match 'GUID:\s*([0-9a-f-]{36})') { return $Matches[1] }
  return $null
}

function PCPower-Format($setting, $value) {
  if ($null -eq $value) { return '?' }

  switch ($setting.Unit) {
    'aspm' { return @('Off', 'Moderate', 'Maximum')[$value] }
    'bool' { return @('Off', 'On')[$value] }
    'boost' { return @('Disabled', 'Enabled', 'Aggressive', 'Efficient Enabled', 'Efficient Aggressive', 'Aggressive At Guaranteed', 'Efficient Aggressive At Guaranteed')[$value] }
    'sched' { return @('All cores', 'P-cores only', 'Prefer P-cores', 'E-cores only', 'Prefer E-cores', 'Automatic')[$value] }
    'cooling' { return @('Passive', 'Active')[$value] }
    's' { if ($value -eq 0) { return 'never' } else { return "${value}s" } }
    default { return "$value$($setting.Unit)" }
  }
}
