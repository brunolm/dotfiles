function Git-ClearLocalGoneBranches() {
  git fetch --all --prune
  git branch -vv `
  | Where-Object { $_ -like '*origin/*: gone*' } `
  | Select-Object -Property @{N = 'Name'; E = { ($_ -split ' ')[2] } } `
  | ForEach-Object { git branch -d $_.Name }
}

function Git-UpdateDevelop() {
  git fetch --all --prune
  git checkout develop
  git pull
}

function Git-UpdateMainAndDevelop() {
  git fetch --all --prune
  git checkout main
  git pull
  git checkout develop
  git pull
}

function Git-ClearLocalMergedBranches() {
  git branch --merged | Where-Object { $_ -notmatch "main|develop" } | ForEach-Object { git branch -d $_.Trim() }
}

function Git-GPGReload() {
  gpg-connect-agent reloadagent /bye
}

function Git-DeleteBranches() {
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

function Git-Squash() {
  $log = git log --oneline -15
  if (-not $log) {
    Write-Host "No commits found."
    return
  }
  $selected = Single-Select -Items $log
  if ($selected) {
    $hash = ($selected -split ' ')[0]
    Write-Host "Will reset --soft to: $selected"
    $confirm = Read-Host "Confirm? (Y/n)"
    if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
      git reset --soft $hash
    }
    else {
      Write-Host "Cancelled."
    }
  }
}

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
