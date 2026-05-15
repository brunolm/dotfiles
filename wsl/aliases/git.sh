## Interactive git helpers. Uses fzf for selection.

git-gpg-reload() {
  gpg-connect-agent reloadagent /bye
}

git-commit-ai() {
  local prompt="Generate a single conventional commit message for this diff. Format: type(scope): description. If relevant, add two newlines after the title to add further context. Output ONLY the message nothing else, do not use any wrappers"
  local model="claude-sonnet-4.6"
  local reasoning="low"
  local msg
  msg=$(git diff --cached | copilot -p "$prompt" -s --model "$model" --reasoning-effort "$reasoning" --allow-all-tools)
  msg="${msg#"${msg%%[![:space:]]*}"}"
  msg="${msg%"${msg##*[![:space:]]}"}"
  if [[ -z "$msg" ]]; then
    echo "No message generated."
    return
  fi
  echo "$msg"
  read -r -p "Use this message? (Y/n) " confirm
  if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
    git commit -m "$msg"
  fi
}

git-branch-select() {
  local all=0 branches sel
  [[ "$1" == "-a" || "$1" == "--all" ]] && all=1
  if (( all )); then
    git fetch --prune
    branches=$(git branch -a --format='%(refname:short)')
  else
    branches=$(git branch --format='%(refname:short)')
  fi
  [[ -z "$branches" ]] && { echo "No branches found."; return; }
  sel=$(echo "$branches" | fzf) || return
  [[ -n "$sel" ]] && git switch "$sel"
}

git-apply-stash() {
  local stashes sel
  stashes=$(git stash list)
  [[ -z "$stashes" ]] && { echo "No stashes found."; return; }
  sel=$(echo "$stashes" | fzf) || return
  [[ -n "$sel" ]] && git stash apply "${sel%%:*}"
}

git-delete-stash() {
  local stashes picks
  stashes=$(git stash list)
  [[ -z "$stashes" ]] && { echo "No stashes found."; return; }
  picks=$(echo "$stashes" | fzf -m) || return
  [[ -z "$picks" ]] && { echo "No stashes selected."; return; }
  echo "Stashes to delete:"
  echo "$picks" | sed 's/^/  - /'
  read -r -p "Confirm? (Y/n) " confirm
  if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
    echo "$picks" | awk -F: '{print $1}' | sort -r | while read -r ref; do
      git stash drop "$ref"
    done
  fi
}

git-delete-branches() {
  local branches picks
  branches=$(git branch --format='%(refname:short)')
  [[ -z "$branches" ]] && { echo "No branches found."; return; }
  picks=$(echo "$branches" | fzf -m) || return
  [[ -z "$picks" ]] && { echo "No branches selected."; return; }
  echo "Branches to delete:"
  echo "$picks" | sed 's/^/  - /'
  read -r -p "Confirm? (Y/n) " confirm
  if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
    echo "$picks" | while read -r b; do git branch -D "$b"; done
  fi
}

git-squash() {
  local log sel hash
  log=$(git log --oneline -15)
  [[ -z "$log" ]] && { echo "No commits found."; return; }
  sel=$(echo "$log" | fzf) || return
  [[ -z "$sel" ]] && return
  hash="${sel%% *}"
  echo "Will reset --soft to: $sel"
  read -r -p "Confirm? (Y/n) " confirm
  if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
    git reset --soft "$hash"
  fi
}

git-worktree-cd() {
  local wts sel
  wts=$(git worktree list)
  [[ -z "$wts" ]] && { echo "No worktrees found."; return; }
  sel=$(echo "$wts" | fzf) || return
  [[ -n "$sel" ]] && cd "${sel%% *}" || return
}
