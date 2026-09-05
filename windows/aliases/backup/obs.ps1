## B-Backup-OBS: zips OBS scenes, profiles and global/user settings (not the plugin cache), plus a restore.ps1 that puts them back
function B-Backup-OBS {
  [CmdletBinding()]
  param(
    [string]$Output = 'obs-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupObs-Items) $Output $DryRun
}

function BBackupObs-Items() {
  return @(
    'AppData/Roaming/obs-studio/basic',
    'AppData/Roaming/obs-studio/global.ini',
    'AppData/Roaming/obs-studio/user.ini'
  )
}
