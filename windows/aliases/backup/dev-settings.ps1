## B-Backup-DevSettings: zips ssh keys, git config, gpg keys and other credential files from the home folder, plus a restore.ps1 that puts them back
function B-Backup-DevSettings {
  [CmdletBinding()]
  param(
    [string]$Output = 'dev-settings-backup.zip',
    [switch]$SkipGpg,
    [switch]$DryRun
  )

  $staging = BBackup-NewStagingDir
  try {
    $files = @(BBackup-CollectFiles (BBackupSettings-HomeItems))
    if (!$SkipGpg) {
      $files += @(BBackupSettings-GpgFiles $staging $DryRun)
    }
    BBackup-HomeBackup $files $Output $DryRun
  }
  finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
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
    'AppData/Roaming/GitHub CLI/hosts.yml', 'AppData/Roaming/GitHub CLI/config.yml',
    '.cargo/credentials.toml'
  )
}
