## B-Backup-Razer: zips Razer Synapse 4 profiles, lighting and Chroma Studio state (the app's Local Storage and IndexedDB) plus Cortex config, with a restore.ps1; quit Synapse from the tray first
function B-Backup-Razer {
  [CmdletBinding()]
  param(
    [string]$Output = 'razer-backup.zip',
    [switch]$Force,
    [switch]$DryRun
  )

  if (!$Force -and (Get-Process -Name RazerAppEngine -ErrorAction SilentlyContinue)) {
    Write-Warning "Razer Synapse is running; quit it from the tray or pass -Force to copy its stores anyway."
    return
  }

  $files = @(BBackup-CollectFiles (BBackupRazer-Items))
  if (!$files) {
    Write-Host "No Razer data found." -ForegroundColor Yellow
    return
  }

  $replaceDirs = (BBackupRazer-ReplaceDirs) | Where-Object { Test-Path -LiteralPath (Join-Path $HOME $_) } | ForEach-Object { BBackup-EntryName (Join-Path $HOME $_) }
  BBackup-HomeBackup $files $Output $DryRun @{ 'replace-dirs.txt' = ($replaceDirs -join "`n") }
  if (!$DryRun) {
    Write-Host "Restore with Synapse closed; it relaunches from the tray service, so quit it right before running restore.ps1." -ForegroundColor DarkGray
  }
}

# Synapse 4 is a web app: device profiles, lighting and Chroma Studio live in its Local
# Storage and IndexedDB, the Razer ID login in the id.razer.com IndexedDB. Absolute paths
# are Cortex settings under ProgramData.
function BBackupRazer-Items() {
  return @(
    'AppData/Local/Razer/RazerAppEngine/User Data/Default/Local Storage',
    'AppData/Local/Razer/RazerAppEngine/User Data/Default/IndexedDB',
    'AppData/Local/Razer/RazerAppEngine/User Data/Default/Preferences',
    'AppData/Local/Razer/RazerAppEngine/User Data/Apps/Common/featureSettings.jws',
    "$env:ProgramData\Razer\RazerCortex\AppConfig.xml",
    "$env:ProgramData\Razer\RazerCortex\AutoSettings.xml",
    "$env:ProgramData\Razer\RazerCortex\Add-onsConfig.xml",
    "$env:ProgramData\Razer\RazerCortex\GameClipBlackList.xml"
  )
}

# LevelDB folders must be swapped whole, never merged with what is already there.
function BBackupRazer-ReplaceDirs() {
  return @(
    'AppData/Local/Razer/RazerAppEngine/User Data/Default/Local Storage',
    'AppData/Local/Razer/RazerAppEngine/User Data/Default/IndexedDB'
  )
}
