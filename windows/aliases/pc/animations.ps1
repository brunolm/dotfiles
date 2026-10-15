# Settings > Accessibility > Visual effects > Animation effects. Browsers map it to
# prefers-reduced-motion, so turning it off freezes most website spinners/transitions.
function B-PC-Set-Animations {
  param(
    [Parameter(Position = 0)]
    [ValidateSet('toggle', 'on', 'off', 'status')]
    [string]$Mode = 'toggle'
  )

  $current = PCAnimations-Get

  if ($Mode -eq 'status') {
    Write-Host "Animations: $(PCAnimations-Label $current)"
    return
  }

  $target = switch ($Mode) {
    'on' { $true }
    'off' { $false }
    default { !$current }
  }

  PCAnimations-Set $target
  Write-Host "Animations: $(PCAnimations-Label $current) -> $(PCAnimations-Label (PCAnimations-Get))"
}

function PCAnimations-Get {
  PCAnimations-LoadType
  $enabled = $false
  [Dotfiles.Animations]::SystemParametersInfo(0x1042, 0, [ref]$enabled, 0) | Out-Null
  $enabled
}

# SPI_SETCLIENTAREAANIMATION takes the BOOL in pvParam itself, not a pointer to it.
# Flags 3 = SPIF_UPDATEINIFILE | SPIF_SENDCHANGE, so it persists and running apps get notified.
function PCAnimations-Set([bool]$enabled) {
  PCAnimations-LoadType
  [Dotfiles.Animations]::SetClientAreaAnimation(0x1043, 0, [IntPtr][int]$enabled, 3) | Out-Null
}

function PCAnimations-LoadType {
  if ('Dotfiles.Animations' -as [type]) {
    return
  }

  Add-Type -Namespace Dotfiles -Name Animations -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool SystemParametersInfo(uint action, uint uiParam, ref bool pvParam, uint winIni);
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SetClientAreaAnimation(uint action, uint uiParam, IntPtr pvParam, uint winIni);
'@
}

function PCAnimations-Label([bool]$enabled) {
  if ($enabled) { 'on' } else { 'off' }
}
