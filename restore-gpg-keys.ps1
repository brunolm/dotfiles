<#
.SYNOPSIS
  Restore a GPG key + ownertrust from public.asc, secret.asc, and
  ownertrust.txt located in the ./backup folder next to this script.
#>

$ErrorActionPreference = 'Stop'

$src    = Join-Path $PSScriptRoot 'backup'
$public = Join-Path $src 'public.asc'
$secret = Join-Path $src 'secret.asc'
$trust  = Join-Path $src 'ownertrust.txt'

foreach ($f in @($public, $secret, $trust)) {
  if (-not (Test-Path $f)) {
    throw "Missing required file: $f"
  }
}

if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
  throw "gpg not found on PATH. Install GnuPG first."
}

Write-Host "==> Importing public key"
gpg --import $public
if ($LASTEXITCODE -ne 0) { throw "public-key import failed (exit $LASTEXITCODE)" }

Write-Host "==> Importing secret key (passphrase prompt will appear)"
gpg --import $secret
if ($LASTEXITCODE -ne 0) { throw "secret-key import failed (exit $LASTEXITCODE)" }

Write-Host "==> Restoring ownertrust"
gpg --import-ownertrust $trust
if ($LASTEXITCODE -ne 0) { throw "ownertrust import failed (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "==> Imported secret keys:"
gpg --list-secret-keys
