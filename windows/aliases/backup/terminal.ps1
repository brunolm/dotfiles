## B-Backup-Terminal: zips Windows Terminal settings, the VS Code mcp.json that Settings Sync skips, and .wslconfig, plus a restore.ps1 that puts them back
function B-Backup-Terminal {
  [CmdletBinding()]
  param(
    [string]$Output = 'terminal-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupTerminal-Items) $Output $DryRun
}

function BBackupTerminal-Items() {
  return @(
    'AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json',
    'AppData/Roaming/Code - Insiders/User/mcp.json',
    '.wslconfig'
  )
}
