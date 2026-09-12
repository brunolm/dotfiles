$BRegAssocAhk2ProgId = 'AutoHotkeyScript.v2'

## B-Reg-Set-Ahk2-Association: makes Explorer run .ahk2 files with AutoHotkey v2 (per-user, no admin); -DryRun reports without writing
function B-Reg-Set-Ahk2-Association {
  [CmdletBinding()]
  param([switch]$DryRun)

  $ahk = "$env:ProgramFiles\AutoHotkey"
  $interpreter = "$ahk\v2\AutoHotkey64.exe"
  if (!(Test-Path -LiteralPath $interpreter)) {
    Write-Error "AutoHotkey v2 is not installed at $interpreter. Run B-Software-Update-AutoHotkey first."
    return
  }

  $changed = 0
  foreach ($entry in (BRegAssoc-Ahk2Entries $ahk $interpreter)) {
    $changed += BRegAssoc-SetDefault $entry.Path $entry.Value $DryRun
  }

  Write-Host ""
  if ($DryRun) {
    Write-Host "Dry run: nothing written." -ForegroundColor Yellow
    return
  }

  Write-Host "$changed key(s) changed." -ForegroundColor Green
  BRegAssoc-WarnOnUserChoice '.ahk2' $BRegAssocAhk2ProgId
  if ($changed) { BRegAssoc-NotifyShell }
}

# .ahk goes through the UX launcher, which guesses the interpreter version from #Requires or from
# the script's syntax. Most .ahk2 files here have no #Requires and parse as either version, so this
# progid skips the launcher and pins v2 — the extension already states the version.
function BRegAssoc-Ahk2Entries($ahk, $interpreter) {
  $classes = 'HKCU:\Software\Classes'
  $progId = "$classes\$BRegAssocAhk2ProgId"
  $ux = "$ahk\UX\AutoHotkeyUX.exe"

  @(
    [pscustomobject]@{ Path = "$classes\.ahk2"; Value = $BRegAssocAhk2ProgId }
    [pscustomobject]@{ Path = $progId; Value = 'AutoHotkey v2 Script' }
    [pscustomobject]@{ Path = "$progId\DefaultIcon"; Value = "$ux,1" }
    [pscustomobject]@{ Path = "$progId\Shell\Open"; Value = 'Run script' }
    [pscustomobject]@{ Path = "$progId\Shell\Open\Command"; Value = "`"$interpreter`" `"%1`" %*" }
    [pscustomobject]@{ Path = "$progId\Shell\UIAccess"; Value = 'Run with UI access' }
    [pscustomobject]@{ Path = "$progId\Shell\UIAccess\Command"; Value = "`"$ahk\v2\AutoHotkey64_UIA.exe`" `"%1`" %*" }
    [pscustomobject]@{ Path = "$progId\Shell\Edit"; Value = 'Edit Script' }
    [pscustomobject]@{ Path = "$progId\Shell\Edit\Command"; Value = "`"$ux`" `"$ahk\UX\ui-editor.ahk`" `"%1`"" }
  )
}

function BRegAssoc-SetDefault($path, $value, $dryRun) {
  $label = $path -replace '^HKCU:\\Software\\Classes\\', ''
  $current = (Get-ItemProperty -LiteralPath $path -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
  if ($current -eq $value) {
    Write-Host ("  ok      {0,-34} = {1}" -f $label, $value) -ForegroundColor DarkGray
    return 0
  }
  if ($dryRun) {
    Write-Host ("  would   {0,-34} -> {1}" -f $label, $value) -ForegroundColor Yellow
    return 0
  }

  if (!(Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -LiteralPath $path -Name '(default)' -Value $value -Type String
  Write-Host ("  set     {0,-34} -> {1}" -f $label, $value) -ForegroundColor Green
  return 1
}

# UserChoice is written when a default app is picked through Explorer. Windows signs it per user and
# gives it priority over HKCU\Software\Classes, so it can only be replaced from the Explorer UI.
function BRegAssoc-WarnOnUserChoice($extension, $progId) {
  $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\UserChoice"
  $choice = (Get-ItemProperty -LiteralPath $path -Name 'ProgId' -ErrorAction SilentlyContinue).ProgId
  if (!$choice -or $choice -eq $progId) { return }

  Write-Host "Explorer has a UserChoice of '$choice' for $extension, which overrides this association." -ForegroundColor Yellow
  Write-Host "Clear it from a $extension file: Open with -> Choose another app -> AutoHotkey v2 Script." -ForegroundColor DarkGray
}

function BRegAssoc-NotifyShell {
  if (!('Dotfiles.ShellAssoc' -as [type])) {
    Add-Type -Namespace Dotfiles -Name ShellAssoc -MemberDefinition @'
[DllImport("shell32.dll")]
public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
'@
  }

  [Dotfiles.ShellAssoc]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
}
