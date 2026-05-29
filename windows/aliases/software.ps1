function Update-SW-GitHubCopilot() {
  $id = 'GitHub.Copilot'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-7Zip() {
  $id = '7zip.7zip'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Chrome() {
  $url = "http://dl.google.com/chrome/install/stable/chrome_installer.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Chrome installer')) { return }
  $file = Join-Path $env:TEMP chrome.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

function Update-SW-Brave() {
  $id = 'Brave.Brave'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Firefox() {
  $id = 'Mozilla.Firefox'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Steam() {
  $url = "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe"
  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'Steam installer')) { return }
  $file = Join-Path $env:TEMP steam.exe
  Invoke-WebRequest $url -OutFile $file
  Start-Process $file
}

function Update-SW-VSCode() {
  $url = "https://code.visualstudio.com/sha/download?build=insider&os=win32-x64"
  $file = Join-Path $env:TEMP "VSCodeInsiders-latest-win-x64.exe"

  if (-not (Confirm-BuildAge -BuiltAt (Get-UrlLastModified $url) -Label 'VS Code Insiders')) { return }

  Write-Host "Downloading VS Code Insiders..." -ForegroundColor Cyan
  Invoke-WebRequest $url -OutFile $file
  Write-Host "Installing..." -ForegroundColor Cyan
  Start-Process $file -ArgumentList "/verysilent", "/mergetasks=!runcode" -Wait
  Write-Host "Done." -ForegroundColor Green
  code-insiders --version
}

function Update-SW-Powershell() {
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

function Update-SW-qTorrent() {
  $id = 'qBittorrent.qBittorrent'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Mise() {
  $id = 'jdx.mise'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Update-SW-Slack() {
  $id = 'SlackTechnologies.Slack'
  if (-not (Confirm-BuildAge -BuiltAt (Get-WingetManifestDate -PackageId $id) -Label "$id manifest")) { return }
  winget install $id
}

function Get-WingetManifestDate {
  param([Parameter(Mandatory)][string]$PackageId)

  $ver = ((winget show $PackageId) | Select-String -Pattern '^Version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
  $parts = $PackageId.Split('.')
  $bucket = $parts[0].Substring(0, 1).ToLower()
  $path = "manifests/$bucket/" + ($parts -join '/') + "/$ver"
  $date = gh api "repos/microsoft/winget-pkgs/commits?path=$path&per_page=1" --jq '.[0].commit.committer.date'
  return [DateTime]$date
}

function Get-UrlLastModified {
  param([Parameter(Mandatory)][string]$Url)
  $head = Invoke-WebRequest $Url -Method Head
  return [DateTime]::Parse($head.Headers.'Last-Modified')
}

function Confirm-BuildAge {
  param(
    [Parameter(Mandatory)][DateTime]$BuiltAt,
    [double]$MinAgeHours = 6,
    [string]$Label = 'Build'
  )

  $builtUtc = $BuiltAt.ToUniversalTime()
  $ageHours = ((Get-Date).ToUniversalTime() - $builtUtc).TotalHours

  if ($ageHours -ge $MinAgeHours) {
    Write-Host ("$Label is {0:N1}h old, proceeding." -f $ageHours) -ForegroundColor Cyan
    return $true
  }

  Write-Host ("$Label is only {0:N1}h old (built {1:u}). It may be unstable." -f $ageHours, $builtUtc) -ForegroundColor Yellow
  $answer = Read-Host "Install anyway? [y/N]"
  if ($answer -match '^(y|yes)$') { return $true }

  Write-Host "Aborted." -ForegroundColor Red
  return $false
}
