function Git-GPGReload() {
  gpg-connect-agent reloadagent /bye
}

function Git-CommitAI() {
  $prompt = "Generate a single conventional commit message for this diff. Format: type(scope): description. If relevant, add two newlines after the title to add further context. Output ONLY the message nothing else, do not use any wrappers"
  $model = "claude-sonnet-4.6"
  $reasoning = "low"
  $lines = git diff --cached | copilot -p $prompt -s --model $model --reasoning-effort $reasoning --allow-all-tools
  $msg = ($lines -join "`n").Trim()
  if (-not $msg) {
    Write-Host "No message generated."
    return
  }
  Write-Host $msg
  $confirm = Read-Host "Use this message? (Y/n)"
  if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
    git commit -m $msg
  }
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

function Git-BranchSelect([switch]$All) {
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

function Git-ApplyStash() {
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

function Git-DeleteStash() {
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

function Git-Worktree-Cd() {
  $worktrees = git worktree list | ForEach-Object { $_.Trim() }
  if (-not $worktrees) {
    Write-Host "No worktrees found."
    return
  }
  $selected = Single-Select -Items $worktrees
  if ($selected) {
    $path = ($selected -split '\s+')[0]
    Set-Location $path
  }
}


Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
