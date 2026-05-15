alias cls=clear

## cdcp: copy current directory to clipboard. Uses clip.exe under WSL,
## wl-copy on Wayland, xclip on X11.
cdcp() {
  local path; path=$(pwd)
  if command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$path" | clip.exe
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$path" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$path" | xclip -selection clipboard
  else
    echo "$path"
  fi
}

## show-info: per-directory environment summary (git, runtimes, AWS, YTM, ...).
show-info() {
  local YELLOW=$'\033[33m' CYAN=$'\033[36m' GREEN=$'\033[32m' BLUE=$'\033[34m' \
        MAGENTA=$'\033[35m' RED=$'\033[31m' DGRAY=$'\033[90m' RESET=$'\033[0m'

  _row() {
    local label="$1" value="$2" color="${3:-$CYAN}"
    printf "%s%-9s%s %s\n" "$color" "$label:" "$RESET" "$value"
  }

  _any_file() {
    local p
    for p in "$@"; do
      compgen -G "$p" >/dev/null 2>&1 && return 0
    done
    return 1
  }

  echo "${YELLOW}=== Prompt Summary ===${RESET}"
  _row Path "$(pwd)" "$YELLOW"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch working staged untracked stash upstream ahead behind parts
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    working=$(git diff --name-only 2>/dev/null | wc -l)
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    stash=$(git stash list 2>/dev/null | wc -l)
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    ahead=0; behind=0
    if [[ -n "$upstream" ]]; then
      ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
      behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null)
    fi
    parts="branch=$branch, upstream=${upstream:-(none)}"
    (( ahead > 0 ))     && parts+=", ahead=$ahead"
    (( behind > 0 ))    && parts+=", behind=$behind"
    (( working > 0 ))   && parts+=", working=$working"
    (( staged > 0 ))    && parts+=", staged=$staged"
    (( untracked > 0 )) && parts+=", untracked=$untracked"
    (( stash > 0 ))     && parts+=", stash=$stash"
    _row Git "$parts" "$CYAN"
  else
    _row Git "(not a git repo)" "$DGRAY"
  fi

  if command -v node >/dev/null 2>&1 && _any_file 'package.json' '.nvmrc' '*.js' '*.cjs' '*.mjs' '*.ts' '*.tsx' '*.jsx'; then
    _row Node "$(node --version | sed 's/^v//')" "$GREEN"
  fi

  if command -v go >/dev/null 2>&1 && _any_file 'go.mod' '*.go'; then
    local gv; gv=$(go version 2>/dev/null | grep -oE 'go[0-9.]+' | head -1 | sed 's/^go//')
    [[ -n "$gv" ]] && _row Go "$gv" "$BLUE"
  fi

  if command -v julia >/dev/null 2>&1 && _any_file '*.jl'; then
    local jv; jv=$(julia --version 2>/dev/null | grep -oE '[0-9.]+' | head -1)
    [[ -n "$jv" ]] && _row Julia "$jv" "$MAGENTA"
  fi

  if command -v python >/dev/null 2>&1 && _any_file '*.py' 'requirements.txt' 'pyproject.toml' 'Pipfile' 'setup.py' 'tox.ini'; then
    local pv; pv=$(python --version 2>&1 | grep -oE '[0-9.]+' | head -1)
    if [[ -n "$pv" ]]; then
      [[ -n "$VIRTUAL_ENV" ]] && pv="$pv (venv: $(basename "$VIRTUAL_ENV"))"
      _row Python "$pv" "$YELLOW"
    fi
  fi

  if command -v ruby >/dev/null 2>&1 && _any_file '*.rb' 'Gemfile' 'Rakefile' '*.gemspec'; then
    local rv; rv=$(ruby --version 2>/dev/null | awk '{print $2}')
    [[ -n "$rv" ]] && _row Ruby "$rv" "$RED"
  fi

  if _any_file 'host.json' 'local.settings.json' 'function.json'; then
    _row AzFunc "(project detected)" "$YELLOW"
  fi

  local awsp="${AWS_PROFILE:-$AWS_DEFAULT_PROFILE}"
  local awsr="${AWS_REGION:-$AWS_DEFAULT_REGION}"
  if [[ -n "$awsp" || -n "$awsr" ]]; then
    local awsparts=""
    [[ -n "$awsp" ]] && awsparts="profile=$awsp"
    if [[ -n "$awsr" ]]; then
      [[ -n "$awsparts" ]] && awsparts+=", "
      awsparts+="region=$awsr"
    fi
    _row AWS "$awsparts" "$YELLOW"
  else
    _row AWS "(no profile in env)" "$DGRAY"
  fi

  if command -v jq >/dev/null 2>&1; then
    local ytm
    if ytm=$(curl -s --max-time 1 http://localhost:9863/query 2>/dev/null) && [[ -n "$ytm" ]]; then
      local has_song; has_song=$(echo "$ytm" | jq -r '.player.hasSong // false' 2>/dev/null)
      if [[ "$has_song" == "true" ]]; then
        local paused state author title
        paused=$(echo "$ytm" | jq -r '.player.isPaused // false')
        state="playing"; [[ "$paused" == "true" ]] && state="paused"
        author=$(echo "$ytm" | jq -r '.track.author // ""')
        title=$(echo "$ytm" | jq -r '.track.title // ""')
        _row YTM "[$state] $author - $title" "$GREEN"
      else
        _row YTM "(stopped)" "$DGRAY"
      fi
    else
      _row YTM "(api unavailable)" "$DGRAY"
    fi
  fi
}

## watch-memory-hogs: tail processes using more than $1 MB of RSS.
watch-memory-hogs() {
  local min_mb="${1:-500}"
  local refresh="${2:-2}"
  local warn_mb="${3:-1024}"
  local crit_mb="${4:-3072}"
  local min_kb=$((min_mb*1024))
  local warn_kb=$((warn_mb*1024))
  local crit_kb=$((crit_mb*1024))

  while true; do
    clear
    echo "Processes using over ${min_mb} MB (warn >= ${warn_mb} MB, critical >= ${crit_mb} MB, refresh ${refresh}s) - Ctrl+C to stop"
    echo "Updated: $(date +%H:%M:%S)"
    echo
    printf '%-7s %-30s %12s %10s\n' PID NAME 'Memory(MB)' 'CPU(s)'
    printf '%-7s %-30s %12s %10s\n' ------- ------------------------------ ------------ ----------
    ps -eo pid,comm,rss,time --no-headers --sort=-rss \
      | awk -v min="$min_kb" -v warn="$warn_kb" -v crit="$crit_kb" '
        $3 >= min {
          color=""; reset=""
          if ($3 >= crit) { color="\033[31m"; reset="\033[0m" }
          else if ($3 >= warn) { color="\033[33m"; reset="\033[0m" }
          printf "%s%-7s %-30.30s %12.1f %10s%s\n", color, $1, $2, $3/1024, $4, reset
        }'
    sleep "$refresh"
  done
}
