function B-Git-DeleteBranches() {
  $branches = git branch --format='%(refname:short)' | ForEach-Object { $_.Trim() }
  $picks = Multi-Select -Items $branches
  if ($picks) {
    Write-Host "Branches to delete:"
    $picks | ForEach-Object { Write-Host "  - $_" }
    $confirm = Read-Host "Confirm? (Y/n)"
    if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
      $picks | ForEach-Object { git branch -D $_ }
    }
    else {
      Write-Host "Cancelled."
    }
  }
  else {
    Write-Host "No branches selected."
  }
}

function B-Git-BranchSelect([switch]$All) {
  if ($All) {
    git fetch --prune
    $branches = git branch -a --format='%(refname:short)' | ForEach-Object { $_.Trim() }
  }
  else {
    $branches = git branch --format='%(refname:short)' | ForEach-Object { $_.Trim() }
  }
  if (-not $branches) {
    Write-Host "No branches found."
    return
  }
  $selected = Single-Select -Items $branches
  if ($selected) {
    git switch $selected
  }
}
