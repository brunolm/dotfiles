## B-Backup-CopyQ: zips the copyq config (ini files and themes, not the clipboard tabs), plus a restore.ps1 that puts it back
function B-Backup-CopyQ {
  [CmdletBinding()]
  param(
    [string]$Output = 'copyq-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupCopyQ-Items) $Output $DryRun
}

# The *.dat tab files hold clipboard contents, including the Passwords tab, so only config goes.
function BBackupCopyQ-Items() {
  return @(
    'AppData/Roaming/copyq/*.ini',
    'AppData/Roaming/copyq/themes'
  )
}
