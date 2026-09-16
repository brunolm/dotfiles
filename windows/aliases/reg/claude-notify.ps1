$BRegClaudeAppId = 'BrunoLM.ClaudeCode'
$BRegClaudeIcon = Join-Path $env:LOCALAPPDATA 'Dotfiles\claude-code.png'

## B-Reg-Register-ClaudeToastAppId: registers the Claude Code toast identity (name + icon) the stop hook notifies under; -DryRun reports without writing
function B-Reg-Register-ClaudeToastAppId {
  [CmdletBinding()]
  param([switch]$DryRun)

  $path = "HKCU:\Software\Classes\AppUserModelId\$BRegClaudeAppId"
  $changed = BRegClaude-SetValue $path 'DisplayName' 'Claude Code' $DryRun

  $icon = BRegClaude-ExportClaudeIcon $DryRun
  if ($icon) { $changed += BRegClaude-SetValue $path 'IconUri' $icon $DryRun }

  BRegClaude-Report $changed $DryRun
}

## B-Reg-Register-ClaudeFocusProtocol: registers the claude-focus: URI the stop-hook toast launches to raise the terminal window; -DryRun reports without writing
function B-Reg-Register-ClaudeFocusProtocol {
  [CmdletBinding()]
  param([switch]$DryRun)

  $handler = Join-Path "${env:HOMEDRIVE}${env:HOMEPATH}" '.claude\hooks\focus-window.ps1'
  if (!(Test-Path -LiteralPath $handler)) {
    Write-Error "The focus handler is not linked at $handler. Run install.ps1 first."
    return
  }

  $key = 'HKCU:\Software\Classes\claude-focus'

  # -WindowStyle Hidden only hides the console after powershell has started, so the window still
  # flashes on screen; conhost --headless gives the handler no window to begin with.
  $command = "conhost.exe --headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$handler`" `"%1`""

  $changed = BRegClaude-SetValue $key '(default)' 'URL:Claude Code Focus' $DryRun
  # Its presence, not its value, is what marks the key as a protocol handler.
  $changed += BRegClaude-SetValue $key 'URL Protocol' '' $DryRun
  $changed += BRegClaude-SetValue "$key\shell\open\command" '(default)' $command $DryRun

  BRegClaude-Report $changed $DryRun
}

function BRegClaude-SetValue($path, $name, $value, $dryRun) {
  $label = "$($path -replace '^HKCU:\\Software\\Classes\\', '')\$name"
  $current = (Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue).$name
  if ($null -ne $current -and $current -eq $value) {
    Write-Host ("  ok      {0,-48} = {1}" -f $label, $value) -ForegroundColor DarkGray
    return 0
  }
  if ($dryRun) {
    Write-Host ("  would   {0,-48} -> {1}" -f $label, $value) -ForegroundColor Yellow
    return 0
  }

  if (!(Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -LiteralPath $path -Name $name -Value $value -Type String
  Write-Host ("  set     {0,-48} -> {1}" -f $label, $value) -ForegroundColor Green
  return 1
}

# A toast icon has to be an image file on disk and Claude Code ships only the .exe, so its largest
# icon is exported once. ExtractAssociatedIcon would cap this at 32x32, which a toast upscales.
function BRegClaude-ExportClaudeIcon($dryRun) {
  if ($dryRun) { return $BRegClaudeIcon }

  $exe = (Get-Command claude.exe -ErrorAction SilentlyContinue).Source
  if (!$exe) { $exe = Join-Path "${env:HOMEDRIVE}${env:HOMEPATH}" '.local\bin\claude.exe' }
  if (!(Test-Path -LiteralPath $exe)) {
    Write-Host "  claude.exe not found; registering without an icon" -ForegroundColor Yellow
    return $null
  }

  if (!('Dotfiles.ClaudeIcon' -as [type])) {
    Add-Type -Namespace Dotfiles -Name ClaudeIcon -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, int[] ids, int count, int flags);
[DllImport("user32.dll")]
public static extern bool DestroyIcon(IntPtr icon);
'@
  }
  Add-Type -AssemblyName System.Drawing

  $handles = New-Object IntPtr[] 1
  $ids = New-Object int[] 1
  if ([Dotfiles.ClaudeIcon]::PrivateExtractIcons($exe, 0, 256, 256, $handles, $ids, 1, 0) -lt 1) {
    Write-Host "  no icon found in $exe; registering without one" -ForegroundColor Yellow
    return $null
  }

  try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $BRegClaudeIcon) -Force | Out-Null
    $bitmap = [System.Drawing.Icon]::FromHandle($handles[0]).ToBitmap()
    try { $bitmap.Save($BRegClaudeIcon, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose() }
  } finally {
    [Dotfiles.ClaudeIcon]::DestroyIcon($handles[0]) | Out-Null
  }

  Write-Host ("  icon    {0,-48} <- {1}" -f $BRegClaudeIcon, $exe) -ForegroundColor DarkGray
  return $BRegClaudeIcon
}

function BRegClaude-Report($changed, $dryRun) {
  Write-Host ""
  if ($dryRun) {
    Write-Host "Dry run: nothing written." -ForegroundColor Yellow
    return
  }

  Write-Host "$changed value(s) changed." -ForegroundColor Green
}
