## B-Backup-Wifi: exports every saved Wi-Fi profile with its password as XML, plus a restore.ps1 that re-adds them with netsh
function B-Backup-Wifi {
  [CmdletBinding()]
  param(
    [string]$Output = 'wifi-backup.zip',
    [switch]$DryRun
  )

  $staging = BBackup-NewStagingDir
  try {
    $dir = Join-Path $staging 'wifi'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $files = if ($DryRun) { BBackupWifi-DryRunEntries } else { BBackupWifi-Export $dir }
    if (!$files) {
      Write-Host "No Wi-Fi profiles found." -ForegroundColor Yellow
      return
    }
    BBackup-HomeBackup @($files) $Output $DryRun @{ 'restore.ps1' = (BBackupWifi-RestoreScript) }
  }
  finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# key=clear writes the passwords in plain text, which is the point of the backup; keep the zip private.
function BBackupWifi-Export($dir) {
  netsh wlan export profile key=clear folder="$dir" | Out-Null
  foreach ($file in Get-ChildItem -LiteralPath $dir -Filter *.xml) {
    [pscustomobject]@{ Path = $file.FullName; Entry = "wifi/$($file.Name)" }
  }
}

# A profile saved on two interfaces is listed twice but exports once.
function BBackupWifi-DryRunEntries() {
  $names = foreach ($line in (netsh wlan show profiles)) {
    if ($line -match '^\s*All User Profile\s*:\s*(.+)$') { $Matches[1].Trim() }
  }
  foreach ($name in ($names | Sort-Object -Unique)) {
    [pscustomobject]@{ Path = $null; Entry = "wifi/$name.xml" }
  }
}

function BBackupWifi-RestoreScript() {
  return @'
<#
.SYNOPSIS
  Re-adds the Wi-Fi profiles in the wifi folder with netsh. From an elevated shell they are
  added for all users, otherwise for the current user only.
#>
param([switch]$DryRun)

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$scope = if ($elevated) { 'all' } else { 'current' }

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'wifi') -Filter *.xml) {
  $name = ([xml](Get-Content -LiteralPath $file.FullName -Raw)).WLANProfile.name
  if ($DryRun) {
    Write-Host "add      $name (user=$scope)"
    continue
  }
  $result = netsh wlan add profile filename="$($file.FullName)" user=$scope
  Write-Host "$name : $result" -ForegroundColor Green
}
'@
}
