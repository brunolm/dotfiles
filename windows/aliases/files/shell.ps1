function touch {
  param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)

  foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p) {
      (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
      continue
    }
    New-Item -Path $p -ItemType File | Out-Null
  }
}

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
    robocopy $empty $path /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Remove-Item $path -Recurse -Force
  }
  Remove-Item $empty -Force
}
