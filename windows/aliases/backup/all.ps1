## B-Backup-All: runs every B-Backup-* alias into one folder (default ~\Downloads\backup-<timestamp>); -ProjectsPath lists the folders B-Backup-ProjectsLocal scans, -Skip names backups to leave out
function B-Backup-All {
  [CmdletBinding()]
  param(
    [string[]]$ProjectsPath = @('C:\BrunoLM\Projects'),
    [string]$Destination,
    [ValidateSet('ProjectsLocal', 'DevSettings', 'AiTools', 'BrowserExtensions', 'Razer', 'Terminal', 'CopyQ', 'ShareX', 'OBS', 'Wifi')]
    [string[]]$Skip = @(),
    [switch]$SkipGpg,
    [switch]$Force,
    [switch]$DryRun
  )

  if (!$Destination) { $Destination = Join-Path $HOME "Downloads\backup-$(Get-Date -Format 'yyyyMMdd-HHmm')" }
  $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
  if (!$DryRun) { New-Item -ItemType Directory -Force -Path $destination | Out-Null }

  $results = foreach ($job in (BBackupAll-Jobs $ProjectsPath $SkipGpg $Force)) {
    if ($Skip -contains $job.Name) {
      [pscustomobject]@{ Backup = $job.Label; Zip = $job.Zip; Result = 'skipped' }
      continue
    }

    Write-Host ""
    Write-Host "### $($job.Label)" -ForegroundColor Cyan
    $zip = Join-Path $destination $job.Zip
    try {
      & $job.Run $zip $DryRun
      $result = if ($DryRun) { 'dry run' }
      elseif (Test-Path -LiteralPath $zip) { '{0:N0} KB' -f ((Get-Item -LiteralPath $zip).Length / 1KB) }
      else { 'nothing written' }
    }
    catch {
      $result = "failed: $($_.Exception.Message)"
    }
    [pscustomobject]@{ Backup = $job.Label; Zip = $job.Zip; Result = $result }
  }

  Write-Host ""
  $results | Format-Table -AutoSize | Out-Host
  if (!$DryRun) { Write-Host "Backups in $destination" -ForegroundColor Green }
}

# One job per backup; ProjectsLocal gets one per scanned folder. Run takes (zip path, dry run).
function BBackupAll-Jobs($projectsPaths, $skipGpg, $force) {
  foreach ($path in $projectsPaths) {
    $leaf = Split-Path $path -Leaf
    [pscustomobject]@{
      Name  = 'ProjectsLocal'
      Label = "ProjectsLocal ($path)"
      Zip   = "projects-local-$leaf.zip"
      Run   = { param($zip, $dryRun) B-Backup-ProjectsLocal $path -Output $zip -DryRun:$dryRun }.GetNewClosure()
    }
  }
  [pscustomobject]@{ Name = 'DevSettings'; Label = 'DevSettings'; Zip = 'dev-settings-backup.zip'; Run = { param($zip, $dryRun) B-Backup-DevSettings -Output $zip -SkipGpg:$skipGpg -DryRun:$dryRun }.GetNewClosure() }
  [pscustomobject]@{ Name = 'AiTools'; Label = 'AiTools'; Zip = 'ai-tools-backup.zip'; Run = { param($zip, $dryRun) B-Backup-AiTools -Output $zip -DryRun:$dryRun } }
  [pscustomobject]@{ Name = 'BrowserExtensions'; Label = 'BrowserExtensions'; Zip = 'browser-extensions-backup.zip'; Run = { param($zip, $dryRun) B-Backup-BrowserExtensions -Output $zip -Force:$force -DryRun:$dryRun }.GetNewClosure() }
  [pscustomobject]@{ Name = 'Razer'; Label = 'Razer'; Zip = 'razer-backup.zip'; Run = { param($zip, $dryRun) B-Backup-Razer -Output $zip -Force:$force -DryRun:$dryRun }.GetNewClosure() }
  [pscustomobject]@{ Name = 'Terminal'; Label = 'Terminal'; Zip = 'terminal-backup.zip'; Run = { param($zip, $dryRun) B-Backup-Terminal -Output $zip -DryRun:$dryRun } }
  [pscustomobject]@{ Name = 'CopyQ'; Label = 'CopyQ'; Zip = 'copyq-backup.zip'; Run = { param($zip, $dryRun) B-Backup-CopyQ -Output $zip -DryRun:$dryRun } }
  [pscustomobject]@{ Name = 'ShareX'; Label = 'ShareX'; Zip = 'sharex-backup.zip'; Run = { param($zip, $dryRun) B-Backup-ShareX -Output $zip -DryRun:$dryRun } }
  [pscustomobject]@{ Name = 'OBS'; Label = 'OBS'; Zip = 'obs-backup.zip'; Run = { param($zip, $dryRun) B-Backup-OBS -Output $zip -DryRun:$dryRun } }
  [pscustomobject]@{ Name = 'Wifi'; Label = 'Wifi'; Zip = 'wifi-backup.zip'; Run = { param($zip, $dryRun) B-Backup-Wifi -Output $zip -DryRun:$dryRun } }
}
