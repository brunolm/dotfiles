<#
.SYNOPSIS
  Installs Git on a fresh Windows machine the same way the README does: Chocolatey through
  winget, then git through Chocolatey. A fresh install blocks scripts, so run it with:
    powershell -ExecutionPolicy Bypass -File E:\essentials.ps1
#>

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

Write-Host "Installing Git" -ForegroundColor Cyan
choco install git -y --no-progress
Write-Host "Done. Open a new shell so git is on the PATH." -ForegroundColor Green
