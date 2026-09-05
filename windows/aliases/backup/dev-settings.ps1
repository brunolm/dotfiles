## B-Backup-DevSettings: zips ssh keys, git config, gpg keys and other credential files from the home folder, plus a restore.ps1 that puts them back
function B-Backup-DevSettings {
  [CmdletBinding()]
  param(
    [string]$Output = 'dev-settings-backup.zip',
    [switch]$SkipGpg,
    [switch]$DryRun
  )

  $staging = Join-Path ([System.IO.Path]::GetTempPath()) "dev-settings-backup-$([System.IO.Path]::GetRandomFileName())"
  New-Item -ItemType Directory -Path $staging | Out-Null
  try {
    $files = [System.Collections.Generic.List[object]]::new()
    $files.AddRange([object[]](BBackupSettings-HomeFiles))
    if (!$SkipGpg) {
      $files.AddRange([object[]](BBackupSettings-GpgFiles $staging $DryRun))
    }

    $restore = Join-Path $staging 'restore.ps1'
    Set-Content -LiteralPath $restore -Value (BBackupSettings-RestoreScript) -Encoding utf8BOM
    $files.Add([pscustomobject]@{ Path = $restore; Entry = 'restore.ps1' })

    foreach ($file in ($files | Sort-Object Entry)) { Write-Host "  $($file.Entry)" }
    Write-Host ""
    if ($DryRun) {
      Write-Host "Dry run: $($files.Count) files would be zipped." -ForegroundColor Yellow
      return
    }

    $zip = BBackup-WriteZip $files $Output
    Write-Host "Wrote $($files.Count) files to $zip" -ForegroundColor Green
    Write-Host "Unzip it anywhere and run restore.ps1 to put the files back." -ForegroundColor DarkGray
  }
  finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function BBackupSettings-HomeFiles() {
  foreach ($item in (BBackupSettings-HomeItems)) {
    $path = Join-Path $HOME $item
    if (!(Test-Path -LiteralPath $path)) { continue }

    $entries = Get-Item -LiteralPath $path -Force
    if ($entries.PSIsContainer) {
      $entries = Get-ChildItem -LiteralPath $path -Recurse -File -Force
    }
    foreach ($entry in $entries) {
      $relative = $entry.FullName.Substring($HOME.Length).TrimStart([char]92).Replace([char]92, [char]47)
      [pscustomobject]@{ Path = $entry.FullName; Entry = "home/$relative" }
    }
  }
}

function BBackupSettings-GpgFiles($staging, $dryRun) {
  $gpg = BBackupSettings-GpgPath
  if (!$gpg) {
    Write-Warning "gpg not found, skipping GPG keys."
    return
  }

  $dir = Join-Path $staging 'gpg'
  New-Item -ItemType Directory -Path $dir | Out-Null
  $public = Join-Path $dir 'public.asc'
  $secret = Join-Path $dir 'secret.asc'
  $trust = Join-Path $dir 'ownertrust.txt'
  if ($dryRun) {
    foreach ($name in 'public.asc', 'secret.asc', 'ownertrust.txt') {
      [pscustomobject]@{ Path = (Join-Path $dir $name); Entry = "gpg/$name" }
    }
    return
  }

  & $gpg --batch --yes --armor --output $public --export
  if ($LASTEXITCODE) { Write-Warning "gpg public key export failed (exit $LASTEXITCODE), skipping GPG keys."; return }
  Write-Host "Exporting GPG secret keys (passphrase prompt may appear)..." -ForegroundColor DarkGray
  & $gpg --yes --armor --output $secret --export-secret-keys
  if ($LASTEXITCODE) { Write-Warning "gpg secret key export failed (exit $LASTEXITCODE), skipping GPG keys."; return }
  & $gpg --export-ownertrust | Out-File -LiteralPath $trust -Encoding ascii

  [pscustomobject]@{ Path = $public; Entry = 'gpg/public.asc' }
  [pscustomobject]@{ Path = $secret; Entry = 'gpg/secret.asc' }
  [pscustomobject]@{ Path = $trust; Entry = 'gpg/ownertrust.txt' }

  $gpgconf = Join-Path (Split-Path $gpg) 'gpgconf.exe'
  if (!(Test-Path -LiteralPath $gpgconf)) { return }
  $revocs = Join-Path (& $gpgconf --list-dirs homedir) 'openpgp-revocs.d'
  if (!(Test-Path -LiteralPath $revocs)) { return }
  foreach ($file in Get-ChildItem -LiteralPath $revocs -File -Filter *.rev) {
    [pscustomobject]@{ Path = $file.FullName; Entry = "gpg/revocs/$($file.Name)" }
  }
}

function BBackupSettings-GpgPath() {
  $configured = git config --global gpg.program 2>$null
  if ($configured -and (Test-Path -LiteralPath $configured)) { return $configured }
  return (Get-Command gpg -ErrorAction SilentlyContinue).Source
}

# Paths relative to the home folder; folders are copied recursively, missing ones are skipped.
function BBackupSettings-HomeItems() {
  return @(
    '.ssh',
    '.gitconfig', '.git-credentials',
    '.gnupg/gpg.conf', '.gnupg/gpg-agent.conf',
    '.npmrc', '.yarnrc', '.bunfig.toml',
    '.netrc', '.pypirc',
    '.aws',
    '.docker/config.json',
    '.kube/config',
    '.config/gh/hosts.yml',
    '.cargo/credentials.toml'
  )
}

function BBackupSettings-RestoreScript() {
  return @'
<#
.SYNOPSIS
  Restores the files in this backup into the home folder and imports the GPG keys.
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
