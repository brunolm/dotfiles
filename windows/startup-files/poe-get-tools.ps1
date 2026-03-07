param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet("poe1", "poe2")]
  [string]$target
)

function Show-Notification {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Text,
    [string]$Title = "PoE Tools",
    [int]$TimeoutMs = 2500
  )

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
  $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
  $notifyIcon.BalloonTipTitle = $Title
  $notifyIcon.BalloonTipText = $Text
  $notifyIcon.Visible = $true
  $notifyIcon.ShowBalloonTip($TimeoutMs)
  Start-Sleep -Milliseconds $TimeoutMs
  $notifyIcon.Dispose()
}

function Get-PoeFilters {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("poe1", "poe2")]
    [string]$Target
  )

  $poe1 = Join-Path $env:USERPROFILE "Documents\My Games\Path of Exile"
  $poe2 = Join-Path $env:USERPROFILE "Documents\My Games\Path of Exile 2"
  $repo = "NeverSinkDev/NeverSink-Filter"

  $targetDir = switch ($Target) {
    "poe1" { $poe1 }
    "poe2" { $poe2 }
  }

  $zipFile = "$Target-filters.zip"
  $extractDir = "$Target-filters"

  if (-not (Test-Path -Path $targetDir)) {
    Write-Error "Target directory does not exist: $targetDir"
    return 1
  }

  Write-Host "Fetching releases from $repo..." -ForegroundColor Cyan

  $jsonParams = "tagName,name"
  # Get releases as JSON and parse
  $releases = gh release list --repo $repo --json $jsonParams --limit 10 | ConvertFrom-Json

  # Filter out alpha versions (those with 'a' in the tag name) and get the latest
  $latestNonAlpha = $releases | Where-Object { $_.tagName -notmatch '[aA]' } | Select-Object -First 1

  if ($null -eq $latestNonAlpha) {
    Write-Error "No non-alpha releases found"
    return 1
  }

  $version = $latestNonAlpha.tagName
  Write-Host "Latest non-alpha release: $version" -ForegroundColor Green
  Write-Host "Release name: $($latestNonAlpha.name)" -ForegroundColor Green

  Write-Host "`nDownloading .zip file..." -ForegroundColor Cyan

  # Download the source code archive with target prefix, overwrite if exists
  gh release download $version --repo $repo --archive=zip -O $zipFile --clobber

  Write-Host "`nDownload completed!" -ForegroundColor Green

  Write-Host "`nExtracting files..." -ForegroundColor Cyan

  # Extract the zip file to a target-prefixed folder
  Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

  Write-Host "Extraction completed!" -ForegroundColor Green

  Write-Host "`nCopying .filter files to $targetDir..." -ForegroundColor Cyan

  # Find extracted release folder (NeverSink-Filter-<version>) under target-prefixed extract folder
  $releaseFolder = Get-ChildItem -Path $extractDir -Directory |
  Where-Object { $_.Name -like "NeverSink-Filter-*" } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

  if ($null -eq $releaseFolder) {
    Write-Error "No extracted NeverSink-Filter-* folder found under $extractDir"
    return 1
  }

  # Copy only top-level .filter files from extracted release folder (non-recursive)
  $filterFiles = Get-ChildItem -Path $releaseFolder.FullName -File -Filter "*.filter"

  if ($filterFiles.Count -eq 0) {
    Write-Error "No .filter files found directly under $($releaseFolder.FullName)"
    return 1
  }

  Copy-Item -Path $filterFiles.FullName -Destination $targetDir -Force
  if (Test-Path -Path $extractDir) {
    Remove-Item -Path $extractDir -Recurse -Force
  }

  $copiedMessage = "Copied $($filterFiles.Count) .filter file(s) to: $targetDir"
  Write-Host $copiedMessage -ForegroundColor Green
  Show-Notification -Text $copiedMessage
  return 0
}

exit (Get-PoeFilters -Target $target)

