function B-PC-Disable-Beep() {
  Set-PSReadlineOption -BellStyle None
  # set-service beep -startuptype disabled
}

function B-PC-Start-Powershell {
  param([switch]$Elevated)

  if ($Elevated) {
    Start-Process wt -ArgumentList pwsh -Verb RunAs
    return
  }

  Start-Process wt -ArgumentList pwsh
}

function B-PC-IsElevated() {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  return ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

B-PC-Disable-Beep
