## B-Reg-Windows-Setup: applies the Windows personalization tweaks (dark mode, left taskbar, quiet Start menu, Explorer defaults, no animations); -DryRun reports without writing, -NoRestart skips the Explorer restart
function B-Reg-Windows-Setup {
  [CmdletBinding()]
  param(
    [switch]$DryRun,
    [switch]$NoRestart
  )

  $changed = 0
  foreach ($group in (BRegSetup-Settings | Group-Object Group)) {
    Write-Host ""
    Write-Host "### $($group.Name)" -ForegroundColor Cyan
    foreach ($setting in $group.Group) {
      $current = (Get-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue).($setting.Name)
      if ("$current" -eq "$($setting.Value)") {
        Write-Host ("  ok      {0,-26} = {1}" -f $setting.Name, $setting.Value) -ForegroundColor DarkGray
        continue
      }

      $shown = if ($null -eq $current) { '(unset)' } else { $current }
      if ($DryRun) {
        Write-Host ("  would   {0,-26} {1} -> {2}" -f $setting.Name, $shown, $setting.Value) -ForegroundColor Yellow
        continue
      }

      try {
        if (!(Test-Path -LiteralPath $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
        Set-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -ErrorAction Stop
        Write-Host ("  set     {0,-26} {1} -> {2}" -f $setting.Name, $shown, $setting.Value) -ForegroundColor Green
        $changed++
      }
      catch [System.UnauthorizedAccessException] {
        Write-Host ("  locked  {0,-26} a machine policy owns this value" -f $setting.Name) -ForegroundColor DarkGray
      }
    }
  }

  $changed += BRegSetup-ClearAnimationBits $DryRun

  Write-Host ""
  if ($DryRun) {
    Write-Host "Dry run: nothing written." -ForegroundColor Yellow
    return
  }

  Write-Host "$changed setting(s) changed." -ForegroundColor Green
  if (!$changed -or $NoRestart) { return }
  Write-Host "Restarting Explorer so the taskbar, Start menu and animation settings take effect." -ForegroundColor DarkGray
  B-Reg-Restart-Explorer
}

## B-Reg-Restart-Explorer: restarts Explorer so taskbar, Start menu and folder settings take effect
function B-Reg-Restart-Explorer() {
  Stop-Process -Name explorer -Force
}

# MinAnimate and MenuShowDelay are REG_SZ holding numbers, everything else is a DWord.
# HideRecommendedSection and DisableSearchBoxSuggestions are documented by Microsoft as
# Enterprise/Education policies, so on Pro they may be ignored; the Start_* values still starve
# the recommended section of content. VisualFXSetting 3 is "custom", which stops Windows from
# overriding the individual animation toggles below.
function BRegSetup-Settings() {
  $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  $personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
  $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
  $policy = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
  $desktop = 'HKCU:\Control Panel\Desktop'

  @(
    [pscustomobject]@{ Group = 'theme'; Path = $personalize; Name = 'AppsUseLightTheme'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'theme'; Path = $personalize; Name = 'SystemUsesLightTheme'; Value = 0; Type = 'DWord' }

    [pscustomobject]@{ Group = 'taskbar'; Path = $advanced; Name = 'TaskbarAl'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'taskbar'; Path = $advanced; Name = 'ShowTaskViewButton'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'taskbar'; Path = $advanced; Name = 'TaskbarDa'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'taskbar'; Path = $advanced; Name = 'TaskbarMn'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'taskbar'; Path = $search; Name = 'SearchboxTaskbarMode'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'taskbar'; Path = $advanced; Name = 'MMTaskbarEnabled'; Value = 0; Type = 'DWord' }

    [pscustomobject]@{ Group = 'start menu'; Path = $advanced; Name = 'Start_TrackProgs'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'start menu'; Path = $advanced; Name = 'Start_TrackDocs'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'start menu'; Path = $advanced; Name = 'Start_IrisRecommendations'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'start menu'; Path = $policy; Name = 'HideRecommendedSection'; Value = 1; Type = 'DWord' }
    [pscustomobject]@{ Group = 'start menu'; Path = $search; Name = 'BingSearchEnabled'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'start menu'; Path = $policy; Name = 'DisableSearchBoxSuggestions'; Value = 1; Type = 'DWord' }

    [pscustomobject]@{ Group = 'explorer'; Path = $advanced; Name = 'HideFileExt'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'explorer'; Path = $advanced; Name = 'Hidden'; Value = 1; Type = 'DWord' }
    [pscustomobject]@{ Group = 'explorer'; Path = $advanced; Name = 'LaunchTo'; Value = 1; Type = 'DWord' }

    [pscustomobject]@{ Group = 'animations'; Path = "$desktop\WindowMetrics"; Name = 'MinAnimate'; Value = '0'; Type = 'String' }
    [pscustomobject]@{ Group = 'animations'; Path = $desktop; Name = 'MenuShowDelay'; Value = '0'; Type = 'String' }
    [pscustomobject]@{ Group = 'animations'; Path = $advanced; Name = 'TaskbarAnimations'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{ Group = 'animations'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 3; Type = 'DWord' }
  )
}

# UserPreferencesMask is a REG_BINARY of packed SPI_SETUSERPREFERENCE flags, so the animation bits
# are cleared in place and the rest of the value is left untouched. Returns the number of changes.
function BRegSetup-ClearAnimationBits($dryRun) {
  $path = 'HKCU:\Control Panel\Desktop'
  $mask = (Get-ItemProperty -LiteralPath $path -Name 'UserPreferencesMask' -ErrorAction SilentlyContinue).UserPreferencesMask
  if (!$mask) {
    Write-Host "  skip    UserPreferencesMask        not set on this machine" -ForegroundColor DarkGray
    return 0
  }

  $updated = [byte[]]$mask.Clone()
  foreach ($bit in (BRegSetup-AnimationBits)) {
    $updated[$bit.Byte] = [byte]($updated[$bit.Byte] -band (0xFF -bxor $bit.Mask))
  }

  $before = ($mask | ForEach-Object { $_.ToString('X2') }) -join ' '
  $after = ($updated | ForEach-Object { $_.ToString('X2') }) -join ' '
  if ($before -eq $after) {
    Write-Host ("  ok      {0,-26} = {1}" -f 'UserPreferencesMask', $after) -ForegroundColor DarkGray
    return 0
  }
  if ($dryRun) {
    Write-Host ("  would   {0,-26} {1} -> {2}" -f 'UserPreferencesMask', $before, $after) -ForegroundColor Yellow
    return 0
  }

  Set-ItemProperty -LiteralPath $path -Name 'UserPreferencesMask' -Value $updated -Type Binary
  Write-Host ("  set     {0,-26} {1} -> {2}" -f 'UserPreferencesMask', $before, $after) -ForegroundColor Green
  return 1
}

function BRegSetup-AnimationBits() {
  @(
    [pscustomobject]@{ Byte = 0; Mask = 0x02 }  # MenuAnimation
    [pscustomobject]@{ Byte = 0; Mask = 0x04 }  # ComboBoxAnimation
    [pscustomobject]@{ Byte = 0; Mask = 0x08 }  # ListBoxSmoothScrolling
    [pscustomobject]@{ Byte = 1; Mask = 0x02 }  # MenuFade
    [pscustomobject]@{ Byte = 1; Mask = 0x04 }  # SelectionFade
    [pscustomobject]@{ Byte = 1; Mask = 0x08 }  # TooltipAnimation
    [pscustomobject]@{ Byte = 1; Mask = 0x10 }  # TooltipFade
    [pscustomobject]@{ Byte = 4; Mask = 0x02 }  # ClientAreaAnimation, the Accessibility "Animation effects" toggle
  )
}
