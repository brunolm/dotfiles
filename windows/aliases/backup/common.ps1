# Shared by the B-Backup-* aliases. Backups that mirror the home folder store files under
# home/<relative path> next to a restore.ps1, so one unzip + one script puts everything back.

# Lists the files to zip, adds restore.ps1, and writes the zip unless dry run.
function BBackup-HomeBackup($files, $output, $dryRun) {
  $staging = BBackup-NewStagingDir
  try {
    $restore = Join-Path $staging 'restore.ps1'
    Set-Content -LiteralPath $restore -Value (BBackup-RestoreScript) -Encoding utf8BOM
    $all = @($files) + [pscustomobject]@{ Path = $restore; Entry = 'restore.ps1' }

    foreach ($file in ($all | Sort-Object Entry)) { Write-Host "  $($file.Entry)" }
    Write-Host ""
    if ($dryRun) {
      Write-Host "Dry run: $($all.Count) files would be zipped." -ForegroundColor Yellow
      return
    }

    $zip = BBackup-WriteZip $all $output
    Write-Host "Wrote $($all.Count) files to $zip" -ForegroundColor Green
    Write-Host "Unzip it anywhere and run restore.ps1 to put the files back." -ForegroundColor DarkGray
  }
  finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Items are paths relative to the home folder and may contain wildcards; folders are
# taken recursively, missing items are skipped, and links are left out because the
# dotfiles install recreates them.
function BBackup-HomeFiles($items) {
  foreach ($item in $items) {
    $found = Get-Item -Path (Join-Path $HOME $item) -Force -ErrorAction SilentlyContinue
    foreach ($match in $found) {
      if ($match.LinkType) { continue }
      $entries = $match
      if ($match.PSIsContainer) {
        $entries = Get-ChildItem -LiteralPath $match.FullName -Recurse -File -Force | Where-Object { !$_.LinkType }
      }
      foreach ($entry in $entries) {
        [pscustomobject]@{ Path = $entry.FullName; Entry = "home/$(BBackup-RelativePath $HOME $entry.FullName)" }
      }
    }
  }
}

function BBackup-NewStagingDir() {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) "b-backup-$([System.IO.Path]::GetRandomFileName())"
  New-Item -ItemType Directory -Path $dir | Out-Null
  return $dir
}

function BBackup-WriteZip($files, $output) {
  $zipPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($output)
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath }

  $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($file in $files) {
      try {
        BBackup-AddZipEntry $archive $file.Path $file.Entry
      }
      catch {
        Write-Warning "Skipped $($file.Entry): $($_.Exception.GetBaseException().Message)"
      }
    }
  }
  finally {
    $archive.Dispose()
  }
  return $zipPath
}

# Opens with shared read/write so files held open by running apps (sqlite databases, jsonl logs) still get copied.
function BBackup-AddZipEntry($archive, $path, $entryName) {
  $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
  $source = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
  try {
    $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = [System.IO.File]::GetLastWriteTime($path)
    $target = $entry.Open()
    try { $source.CopyTo($target) }
    finally { $target.Dispose() }
  }
  finally {
    $source.Dispose()
  }
}

function BBackup-RelativePath($base, $path) {
  return $path.Substring($base.Length).TrimStart([char]92).Replace([char]92, [char]47)
}

function BBackup-RestoreScript() {
  return @'
<#
.SYNOPSIS
  Restores the files in this backup into the home folder and imports the GPG keys if present.
  Existing files are renamed to *.bak-<timestamp>; destinations that are links are left alone.
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$homeDir = Join-Path $PSScriptRoot 'home'
if (Test-Path -LiteralPath $homeDir) {
  foreach ($file in Get-ChildItem -LiteralPath $homeDir -Recurse -File -Force) {
    $relative = $file.FullName.Substring($homeDir.Length + 1)
    $target = Join-Path $HOME $relative
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType) {
      Write-Host "skip     $relative (destination is a link)" -ForegroundColor DarkGray
      continue
    }
    if ($DryRun) {
      Write-Host "restore  $relative"
      continue
    }
    if ($existing) {
      Rename-Item -LiteralPath $target -NewName "$($existing.Name).bak-$stamp"
      Write-Host "moved    $relative -> $($existing.Name).bak-$stamp" -ForegroundColor Yellow
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target
    Write-Host "restored $relative" -ForegroundColor Green
  }

  if (!$DryRun -and (Test-Path -LiteralPath (Join-Path $homeDir '.ssh'))) {
    $ssh = Join-Path $HOME '.ssh'
    icacls $ssh /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
    Write-Host "locked down permissions on $ssh" -ForegroundColor Green
  }
}

$gpgDir = Join-Path $PSScriptRoot 'gpg'
if (Test-Path -LiteralPath $gpgDir) {
  $gpg = $null
  if (Get-Command git -ErrorAction SilentlyContinue) { $gpg = git config --global gpg.program 2>$null }
  if (!$gpg -or !(Test-Path -LiteralPath $gpg)) { $gpg = (Get-Command gpg -ErrorAction SilentlyContinue).Source }

  if (!$gpg) {
    Write-Warning "gpg not found. Install GnuPG and import gpg\public.asc, gpg\secret.asc and gpg\ownertrust.txt manually."
  }
  elseif ($DryRun) {
    Write-Host "import   gpg keys using $gpg"
  }
  else {
    Write-Host "importing GPG keys (passphrase prompt will appear)" -ForegroundColor DarkGray
    & $gpg --import (Join-Path $gpgDir 'public.asc')
    & $gpg --import (Join-Path $gpgDir 'secret.asc')
    & $gpg --import-ownertrust (Join-Path $gpgDir 'ownertrust.txt')

    $revocs = Join-Path $gpgDir 'revocs'
    $gpgconf = Join-Path (Split-Path $gpg) 'gpgconf.exe'
    if ((Test-Path -LiteralPath $revocs) -and (Test-Path -LiteralPath $gpgconf)) {
      $dest = Join-Path (& $gpgconf --list-dirs homedir) 'openpgp-revocs.d'
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Copy-Item -Path (Join-Path $revocs '*.rev') -Destination $dest
      Write-Host "restored revocation certificates to $dest" -ForegroundColor Green
    }
    & $gpg --list-secret-keys
  }
}
'@
}
