## B-Backup-ShareX: zips the ShareX application, hotkeys and uploaders config (not history or screenshots), plus a restore.ps1 that puts it back
function B-Backup-ShareX {
  [CmdletBinding()]
  param(
    [string]$Output = 'sharex-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupShareX-Items) $Output $DryRun
}

# UploadersConfig.json carries the upload service tokens; keep the zip private.
function BBackupShareX-Items() {
  return @(
    'Documents/ShareX/ApplicationConfig.json',
    'Documents/ShareX/HotkeysConfig.json',
    'Documents/ShareX/UploadersConfig.json'
  )
}
