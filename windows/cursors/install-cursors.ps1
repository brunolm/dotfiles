# Installs the BrunoLM cursor scheme: copies the .cur files to a stable
# location, registers them as a user scheme, sets them active, and applies
# the change live via SystemParametersInfo (no logoff needed).
$schemeName = "BrunoLM"
$src = Join-Path $PSScriptRoot "brunolm"
# Registry paths must survive a dotfiles repo move, so copy instead of linking
$dest = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Cursors\$schemeName"

if (!(Test-Path (Join-Path $src "arrow.ani")) -and !(Test-Path (Join-Path $src "arrow.cur"))) {
  Write-Error "No cursor files found in $src"
  exit 1
}

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Path (Join-Path $src "*.cur") -Destination $dest -Force
Copy-Item -Path (Join-Path $src "*.ani") -Destination $dest -Force -ErrorAction SilentlyContinue

# Registry value name -> cursor file. Roles without a file fall back to the
# arrow so a partial cursor set still installs cleanly.
$roles = [ordered]@{
  Arrow       = "arrow"
  Help        = "help"
  AppStarting = "appstarting"
  Wait        = "wait"
  Crosshair   = "crosshair"
  IBeam       = "ibeam"
  NWPen       = "nwpen"
  No          = "no"
  SizeNS      = "sizens"
  SizeWE      = "sizewe"
  SizeNWSE    = "sizenwse"
  SizeNESW    = "sizenesw"
  SizeAll     = "sizeall"
  UpArrow     = "uparrow"
  Hand        = "hand"
  Person      = "person"
  Pin         = "pin"
}

function Resolve-CursorFile([string]$baseName) {
  foreach ($ext in ".ani", ".cur") {
    $candidate = Join-Path $dest "$baseName$ext"
    if (Test-Path $candidate) { return $candidate }
  }
  return Join-Path $dest "arrow.cur"
}

$cursorsKey = "HKCU:\Control Panel\Cursors"
$paths = [ordered]@{}
foreach ($role in $roles.Keys) {
  $paths[$role] = Resolve-CursorFile $roles[$role]
  Set-ItemProperty -Path $cursorsKey -Name $role -Value $paths[$role] -Type ExpandString
}
Set-ItemProperty -Path $cursorsKey -Name "(Default)" -Value $schemeName
# Scheme Source 1 = user-defined scheme
Set-ItemProperty -Path $cursorsKey -Name "Scheme Source" -Value 1 -Type DWord

# Register under Schemes so it shows up in the Mouse control panel dropdown.
# The scheme string is the classic 15-role comma list (Person/Pin excluded).
$schemeRoles = @("Arrow", "Help", "AppStarting", "Wait", "Crosshair", "IBeam",
  "NWPen", "No", "SizeNS", "SizeWE", "SizeNWSE", "SizeNESW", "SizeAll", "UpArrow", "Hand")
$schemeValue = ($schemeRoles | ForEach-Object { $paths[$_] }) -join ","
$schemesKey = "HKCU:\Control Panel\Cursors\Schemes"
if (!(Test-Path $schemesKey)) { New-Item -Path $schemesKey -Force | Out-Null }
Set-ItemProperty -Path $schemesKey -Name $schemeName -Value $schemeValue -Type ExpandString

# SPI_SETCURSORS (0x57) with SPIF_UPDATEINIFILE | SPIF_SENDCHANGE (0x03)
Add-Type -Namespace Dotfiles -Name CursorRefresh -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, System.IntPtr pvParam, uint fWinIni);
'@
[Dotfiles.CursorRefresh]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 0x03) | Out-Null

Write-Host "Cursor scheme '$schemeName' installed and applied from $dest"
