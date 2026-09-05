# Generic install keys select the edition during setup only; they never activate Windows.
$script:WindowsEditions = @{
  Home      = @{ Id = 'Core';         Key = 'YTMG3-N6DKC-DKB77-7M9GH-8HVX7' }
  Pro       = @{ Id = 'Professional'; Key = 'VK7JG-NPHTM-C97JM-9MPGT-3V66T' }
  Education = @{ Id = 'Education';    Key = 'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY' }
}

## B-USB-Add-WindowsEditionPicker: writes sources\ei.cfg on a Windows install USB so setup asks which edition to install instead of silently picking the firmware OEM key's edition; -Edition Home|Pro|Education skips the picker and forces that edition (also works with the 24H2+ setup, which ignores the picker file)
function B-USB-Add-WindowsEditionPicker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Drive,
    [ValidateSet('Home', 'Pro', 'Education')]
    [string]$Edition
  )

  $sources = $Drive.TrimEnd(':', '\', '/') + ':\sources'
  if (!(Test-Path -LiteralPath $sources -PathType Container)) {
    throw "$sources not found; is $Drive a Windows install USB?"
  }

  $eiCfg = "$sources\ei.cfg"
  $pidTxt = "$sources\PID.txt"
  if (!$Edition) {
    Set-Content -LiteralPath $eiCfg -Value "[Channel]`r`n_Default`r`n[VL]`r`n0`r`n" -NoNewline -Encoding ascii
    Remove-Item -LiteralPath $pidTxt -ErrorAction SilentlyContinue
    Write-Host "Wrote $eiCfg (setup will ask which edition to install)" -ForegroundColor Green
    return
  }

  $info = $script:WindowsEditions[$Edition]
  Set-Content -LiteralPath $eiCfg -Value "[EditionID]`r`n$($info.Id)`r`n[Channel]`r`nRetail`r`n[VL]`r`n0`r`n" -NoNewline -Encoding ascii
  Set-Content -LiteralPath $pidTxt -Value "[PID]`r`nValue=$($info.Key)`r`n" -NoNewline -Encoding ascii
  Write-Host "Wrote $eiCfg and $pidTxt (setup will install Windows 11 $Edition)" -ForegroundColor Green
}
