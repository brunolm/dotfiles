## claude-ask: ask Claude a prompt non-interactively and return the result inline.
claude-ask() {
  local args=(-p)
  if [[ "$1" == "--effort" ]]; then
    case "$2" in
      low|medium|high|xhigh|max) args+=(--effort "$2"); shift 2 ;;
      *) echo "claude-ask: invalid effort '$2' (expected low|medium|high|xhigh|max)" >&2; return 2 ;;
    esac
  fi
  args+=("$*")
  claude "${args[@]}"
}

## claude-ask-simple: ask Claude with empty stdin so it runs non-interactively.
## Usage: claude-ask-simple [--model X] [--effort X] [--permission-mode X] <prompt>
claude-ask-simple() {
  local prompt=""
  local model="claude-opus-4-7"
  local effort="xhigh"
  local permission_mode="auto"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)           model="$2"; shift 2 ;;
      --effort)          effort="$2"; shift 2 ;;
      --permission-mode) permission_mode="$2"; shift 2 ;;
      *)                 prompt="$1"; shift ;;
    esac
  done
  local out
  out=$(mktemp)
  claude --model "$model" --effort "$effort" --permission-mode "$permission_mode" -- "$prompt" </dev/null >"$out"
  cat "$out"
  rm -f "$out"
}
