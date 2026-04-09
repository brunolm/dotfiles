function rm-nuke($path, [switch]$dryRun) {
  if (-not (Test-Path $path)) {
    Write-Error "Path '$path' does not exist."
    return
  }
  $empty = Join-Path $env:TEMP "rm-nuke-empty"
  New-Item -ItemType Directory -Path $empty -Force | Out-Null
  if ($dryRun) {
    robocopy $empty $path /MIR /L
  }
  else {
    robocopy $empty $path /MIR
    Remove-Item $path -Recurse -Force
  }
  Remove-Item $empty -Force
}
