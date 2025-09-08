param()

$baseFile = Join-Path $PSScriptRoot 'base.filter'
$marker = '#=== BASE.FILTER PREPEND END ==='

if (-not (Test-Path $baseFile)) {
  Write-Error "Base filter file '$baseFile' does not exist."
  exit 1
}

$files = Get-ChildItem -Path $PSScriptRoot -Filter 'Default_*.filter' -File
foreach ($file in $files) {
  $targetFile = $file.FullName
  $content = Get-Content $targetFile -Raw
  if ($content -match [regex]::Escape($marker)) {
    $content = $content -split [regex]::Escape($marker), 2
    $content = $content[1].TrimStart()
  }
  $baseContent = Get-Content $baseFile -Raw
  $newContent = "$baseContent`r`n$marker`r`n$content"
  Set-Content -Path $targetFile -Value $newContent
  Write-Host "Updated: $targetFile"
}
