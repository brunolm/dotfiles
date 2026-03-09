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

function Get-AwekenedPoeTrade {
  $repo = "SnosMe/awakened-poe-trade"
  $destinationDir = "C:\BrunoLM\Games\PoE"

  if (-not (Test-Path -Path $destinationDir)) {
    Write-Error "Destination directory does not exist: $destinationDir"
    return 1
  }

  Write-Host "Fetching latest release from $repo..." -ForegroundColor Cyan
  $latestRelease = gh api "repos/$repo/releases/latest" | ConvertFrom-Json

  if ($null -eq $latestRelease -or [string]::IsNullOrWhiteSpace($latestRelease.tag_name)) {
    Write-Error "Could not determine latest release"
    return 1
  }

  $tagName = $latestRelease.tag_name
  $version = $tagName.TrimStart('v', 'V')
  $assetName = "Awakened-PoE-Trade-$version.exe"

  Write-Host "Downloading $assetName..." -ForegroundColor Cyan
  gh release download $tagName --repo $repo --pattern $assetName --clobber

  if (-not (Test-Path -Path $assetName)) {
    Write-Error "Expected asset not found after download: $assetName"
    return 1
  }

  $destinationFile = Join-Path $destinationDir "awakened-poe-trade.exe"
  Copy-Item -Path $assetName -Destination $destinationFile -Force

  $versionFile = Join-Path $destinationDir "$version.txt"
  Set-Content -Path $versionFile -Value $version -Encoding ascii

  $message = "Downloaded $assetName to $destinationFile (version marker: $version.txt)"
  Write-Host $message -ForegroundColor Green
  Show-Notification -Text $message -Title "Awakened PoE Trade"
  return 0
}

function Invoke-PoeTools {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("poe1", "poe2")]
    [string]$Target
  )

  $jobs = @()
  $showNotificationDef = ${function:Show-Notification}.ToString()
  $getPoeFiltersDef = ${function:Get-PoeFilters}.ToString()
  $getAwekenedPoeTradeDef = ${function:Get-AwekenedPoeTrade}.ToString()

  $jobs += Start-Job -Name "Get-PoeFilters" -ScriptBlock {
    param($InnerTarget, $ShowNotificationDef, $GetPoeFiltersDef)
    Set-Item -Path Function:\Show-Notification -Value $ShowNotificationDef
    Set-Item -Path Function:\Get-PoeFilters -Value $GetPoeFiltersDef
    Get-PoeFilters -Target $InnerTarget
  } -ArgumentList $Target, $showNotificationDef, $getPoeFiltersDef

  if ($Target -eq "poe1") {
    $jobs += Start-Job -Name "Get-AwekenedPoeTrade" -ScriptBlock {
      param($ShowNotificationDef, $GetAwekenedPoeTradeDef)
      Set-Item -Path Function:\Show-Notification -Value $ShowNotificationDef
      Set-Item -Path Function:\Get-AwekenedPoeTrade -Value $GetAwekenedPoeTradeDef
      Get-AwekenedPoeTrade
    } -ArgumentList $showNotificationDef, $getAwekenedPoeTradeDef
  }

  Wait-Job -Job $jobs | Out-Null

  $failed = $false
  foreach ($job in $jobs) {
    $output = Receive-Job -Job $job

    if ($job.State -ne "Completed") {
      Write-Error "Job failed: $($job.Name)"
      $failed = $true
      continue
    }

    $exitCode = 1
    if ($output -is [System.Array] -and $output.Count -gt 0 -and $output[-1] -is [int]) {
      $exitCode = [int]$output[-1]
    }
    elseif ($output -is [int]) {
      $exitCode = [int]$output
    }

    if ($exitCode -ne 0) {
      Write-Error "Function failed in job $($job.Name) with code $exitCode"
      $failed = $true
    }
  }

  Remove-Job -Job $jobs -Force

  if ($failed) {
    return 1
  }

  return 0
}

exit (Invoke-PoeTools -Target $target)

