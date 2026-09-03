function B-Git-ApplyStash() {
  $stashes = git stash list
  if (-not $stashes) {
    Write-Host "No stashes found."
    return
  }
  $selected = Single-Select -Items $stashes
  if ($selected) {
    $ref = ($selected -split ':')[0]
    git stash apply $ref
  }
}

function B-Git-DeleteStash() {
  $stashes = git stash list
  if (-not $stashes) {
    Write-Host "No stashes found."
    return
  }
  $picks = Multi-Select -Items $stashes
  if ($picks) {
    Write-Host "Stashes to delete:"
    $picks | ForEach-Object { Write-Host "  - $_" }
    $confirm = Read-Host "Confirm? (Y/n)"
    if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
      $refs = $picks | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Descending
      $refs | ForEach-Object { git stash drop $_ }
    }
    else {
      Write-Host "Cancelled."
    }
  }
  else {
    Write-Host "No stashes selected."
  }
}
