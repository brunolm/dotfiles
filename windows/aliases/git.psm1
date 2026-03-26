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

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
