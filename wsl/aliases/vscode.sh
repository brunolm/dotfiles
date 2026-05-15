## code: prefer code-insiders when present (mirrors the Windows override).
code() {
  if command -v code-insiders >/dev/null 2>&1; then
    code-insiders -n "$@"
  else
    command code "$@"
  fi
}
