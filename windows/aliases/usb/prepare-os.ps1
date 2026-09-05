## B-USB-PrepareOS: prepares a Windows install USB for a fresh machine: writes the edition picker (or -Edition Home|Pro|Education) and copies essentials.ps1 to the USB root so Git can be installed right after setup
function B-USB-PrepareOS {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Drive,
    [ValidateSet('Home', 'Pro', 'Education')]
    [string]$Edition
  )

  B-USB-Add-WindowsEditionPicker @PSBoundParameters

  $root = $Drive.TrimEnd(':', '\', '/') + ':\'
  Copy-Item -LiteralPath (BUsb-RepoFile 'windows\usb\essentials.ps1') -Destination $root -Force
  Write-Host "Copied essentials.ps1 to $root" -ForegroundColor Green
}

# ~/aliases/dotfiles is a symlink to windows/aliases in the repo; resolve it to reach files outside the aliases tree.
function BUsb-RepoFile($relative) {
  $aliases = Get-Item -LiteralPath (Split-Path $PSScriptRoot)
  $real = if ($aliases.Target) { $aliases.Target } else { $aliases.FullName }
  $file = Join-Path (Split-Path (Split-Path $real)) $relative
  if (!(Test-Path -LiteralPath $file)) { throw "$file not found" }
  return $file
}
