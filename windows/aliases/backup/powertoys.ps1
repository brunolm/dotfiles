## B-Backup-PowerToys: zips the PowerToys settings (module toggles, every module's hotkeys and options, Keyboard Manager remaps), plus a restore.ps1 that puts them back
function B-Backup-PowerToys {
  [CmdletBinding()]
  param(
    [string]$Output = 'powertoys-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupPowerToys-Items) $Output $DryRun
}

# Module on/off toggles sit in the root settings.json, each module keeps its hotkeys and
# options in its own settings.json, and Keyboard Manager stores remaps in default.json.
# Caches, logs and update state under the same folder are left out.
function BBackupPowerToys-Items() {
  return @(
    'AppData/Local/Microsoft/PowerToys/settings.json',
    'AppData/Local/Microsoft/PowerToys/*/settings.json',
    'AppData/Local/Microsoft/PowerToys/Keyboard Manager/default.json'
  )
}
