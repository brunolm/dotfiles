<#
.SYNOPSIS
  Bootstraps a fresh Windows machine the same way the README does: Chocolatey through winget,
  git through Chocolatey, then clones dotfiles over HTTPS (the SSH keys come back later from
  the backups). A fresh install blocks scripts, so run it with:
    powershell -ExecutionPolicy Bypass -File E:\essentials.ps1
#>

$repo = 'C:\BrunoLM\Projects\dotfiles'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (!([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run from an elevated PowerShell; the installers need admin."
  return
}

if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Chocolatey" -ForegroundColor Cyan
  winget install --id Chocolatey.Chocolatey -e --accept-source-agreements --accept-package-agreements
  $env:Path += ";$env:ProgramData\chocolatey\bin"
}

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Git" -ForegroundColor Cyan
  choco install git -y --no-progress
  $env:Path += ";$env:ProgramFiles\Git\cmd"
}

if (Test-Path -LiteralPath $repo) {
  Write-Host "$repo already exists, skipping clone" -ForegroundColor Yellow
}
else {
  Write-Host "Cloning dotfiles into $repo" -ForegroundColor Cyan
  New-Item -ItemType Directory -Path (Split-Path $repo) -Force | Out-Null
  git clone https://github.com/brunolm/dotfiles $repo
}

Write-Host "Done. Open a new shell, then in $repo run install.ps1 and install-software.ps1 (see README)." -ForegroundColor Green
