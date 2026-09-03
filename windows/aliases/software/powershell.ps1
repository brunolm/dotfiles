function B-Software-Update-Powershell() {
  Write-Host "Checking latest PowerShell release..." -ForegroundColor Cyan
  $release = gh release view --repo PowerShell/PowerShell --json assets,publishedAt,tagName | ConvertFrom-Json
  $version = $release.tagName -replace '^v', ''
  Write-Host "Latest version: $version (published $([DateTime]$release.publishedAt))" -ForegroundColor Cyan

  $asset = ($release.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1).url
  if (-not (Confirm-BuildAge -BuiltAt ([DateTime]$release.publishedAt) -Label 'Release')) { return }

  $file = Join-Path $env:TEMP "PowerShell-latest-win-x64.msi"
  $log = Join-Path $env:TEMP "PowerShell-install.log"
  Write-Host "Downloading PowerShell $version..." -ForegroundColor Cyan
  Invoke-WebRequest $asset -OutFile $file
  Write-Host "Installing PowerShell $version..." -ForegroundColor Cyan
  Start-Process msiexec.exe -ArgumentList "/i", $file, "/qn", "/norestart", "/l*v", $log -Wait
  Write-Host "Done. Install log: $log" -ForegroundColor Green
}
