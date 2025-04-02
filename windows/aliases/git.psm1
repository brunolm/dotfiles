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

function Git-ClearLocalMergedBranches() {
  git branch --merged | Where-Object { $_ -notmatch "main|develop" } | ForEach-Object { git branch -d $_.Trim() }
}

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
