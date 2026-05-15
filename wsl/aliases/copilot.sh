## start-copilot: launch copilot with --allow-tool flags read from Claude Code settings.
start-copilot() {
  local settings="$HOME/.claude/settings.json"
  local args=()
  if [[ -f "$settings" ]] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r entry; do
      if [[ "$entry" =~ ^Bash\((.+)\)$ ]]; then
        args+=("--allow-tool=shell(${BASH_REMATCH[1]})")
      elif [[ "$entry" =~ ^WebFetch\(domain:(.+)\)$ ]]; then
        args+=("--allow-url=${BASH_REMATCH[1]}")
      fi
    done < <(jq -r '.permissions.allow[]?' "$settings")
  fi
  copilot "${args[@]}" "$@"
}
