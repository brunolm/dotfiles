param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet("poe1", "poe2")]
  [string]$target
)

$poe1 = Join-Path $env:USERPROFILE "Documents\My Games\Path of Exile"
$poe2 = Join-Path $env:USERPROFILE "Documents\My Games\Path of Exile 2"

$repo = "NeverSinkDev/NeverSink-Filter"

$targetDir = switch ($target) {
  "poe1" { $poe1 }
  "poe2" { $poe2 }
}

$zipFile = "$target-filters.zip"
$extractDir = "$target-filters"

if (-not (Test-Path -Path $targetDir)) {
  Write-Error "Target directory does not exist: $targetDir"
  exit 1
}

Write-Host "Fetching releases from $repo..." -ForegroundColor Cyan

$jsonParams = "tagName,name"
# Get releases as JSON and parse
$releases = gh release list --repo $repo --json $jsonParams --limit 10 | ConvertFrom-Json

# Filter out alpha versions (those with 'a' in the tag name) and get the latest
$latestNonAlpha = $releases | Where-Object { $_.tagName -notmatch '[aA]' } | Select-Object -First 1

if ($null -eq $latestNonAlpha) {
  Write-Error "No non-alpha releases found"
  exit 1
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
  exit 1
}

# Copy only top-level .filter files from extracted release folder (non-recursive)
$filterFiles = Get-ChildItem -Path $releaseFolder.FullName -File -Filter "*.filter"

if ($filterFiles.Count -eq 0) {
  Write-Error "No .filter files found directly under $($releaseFolder.FullName)"
  exit 1
}

Copy-Item -Path $filterFiles.FullName -Destination $targetDir -Force

Write-Host "Copied $($filterFiles.Count) .filter file(s) to: $targetDir" -ForegroundColor Green

