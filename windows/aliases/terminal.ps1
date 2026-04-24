function rm-rf {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  Remove-Item -Path $Path -Recurse -Force
}

function cdcp {
  (Get-Location).Path | clip
}

function Multi-Select {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items
  )

  $selected = [bool[]]::new($Items.Count)
  $pos = 0

  function Render {
    [Console]::SetCursorPosition(0, $startY)
    for ($i = 0; $i -lt $Items.Count; $i++) {
      $check = if ($selected[$i]) { 'x' } else { ' ' }
      $prefix = if ($i -eq $pos) { '>' } else { ' ' }
      Write-Host "$prefix [$check] $($Items[$i])                    "
    }
    Write-Host "`nUse Up/Down to move, Space to toggle, Enter to confirm" -NoNewline
  }

  $startY = [Console]::CursorTop
  Render

  while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
      'UpArrow' { if ($pos -gt 0) { $pos-- } }
      'DownArrow' { if ($pos -lt $Items.Count - 1) { $pos++ } }
      'Spacebar' { $selected[$pos] = !$selected[$pos] }
      'Enter' { break }
    }
    if ($key.Key -eq 'Enter') { break }
    Render
  }

  Write-Host "`n"
  $picks = for ($i = 0; $i -lt $Items.Count; $i++) { if ($selected[$i]) { $Items[$i] } }
  return $picks
}

function Single-Select {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items
  )

  $pos = 0

  function Render {
    [Console]::SetCursorPosition(0, $startY)
    for ($i = 0; $i -lt $Items.Count; $i++) {
      $prefix = if ($i -eq $pos) { '>' } else { ' ' }
      Write-Host "$prefix $($Items[$i])                    "
    }
    Write-Host "`nUse Up/Down to move, Enter to confirm" -NoNewline
  }

  $startY = [Console]::CursorTop
  Render

  while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
      'UpArrow' { if ($pos -gt 0) { $pos-- } }
      'DownArrow' { if ($pos -lt $Items.Count - 1) { $pos++ } }
      'Enter' { break }
    }
    if ($key.Key -eq 'Enter') { break }
    Render
  }

  Write-Host "`n"
  return $Items[$pos]
}

