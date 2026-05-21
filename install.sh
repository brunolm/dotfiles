#!/usr/bin/env bash
# install.sh — set up WSL: install zsh, port custom env from ~/.bashrc to ~/.zshrc,
# and optionally sync SSH / Claude / Codex settings from Windows.
# Idempotent: marker-delimited block in ~/.zshrc is refreshed in place; copies overwrite.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_DIR="$SCRIPT_DIR/wsl/aliases"

log() { printf '==> %s\n' "$*"; }

prompt_yn() {
  local question="$1" reply
  if [[ ! -t 0 ]]; then
    log "stdin is not a TTY; skipping: $question"
    return 1
  fi
  read -r -p "$question [y/N] " reply
  case "${reply,,}" in
    y|yes) return 0 ;;
    *)     return 1 ;;
  esac
}

# Echoes the WSL path of Windows %USERPROFILE%, or returns non-zero if unavailable.
resolve_win_home() {
  if ! command -v wslpath >/dev/null 2>&1; then
    log "wslpath not found; cannot resolve Windows home"
    return 1
  fi
  local raw
  raw=$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n' || true)
  if [[ -z "$raw" ]]; then
    log "could not resolve Windows %USERPROFILE% via cmd.exe"
    return 1
  fi
  wslpath "$raw"
}

# Copy a file or directory, dereferencing symlinks so WSL gets real content.
copy_item() {
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    log "  skip (not present): $src"
    return 0
  fi
  log "  copy: $src -> $dst"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    cp -aL "$src/." "$dst/"
  else
    mkdir -p "$(dirname "$dst")"
    cp -aL "$src" "$dst"
  fi
}

# Insert or refresh a marker-delimited block in a file. Idempotent.
upsert_block() {
  local file="$1" begin="$2" end="$3" content="$4"
  if grep -qF "$begin" "$file" 2>/dev/null; then
    log "refreshing block in $file: $begin"
    awk -v b="$begin" -v e="$end" '
      !skip && $0==b { skip=1; next }
       skip && $0==e { skip=0; next }
      !skip { print }
    ' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
  else
    log "adding block to $file: $begin"
  fi
  printf '\n%s\n' "$content" >> "$file"
}

# Translate Windows-style paths to /mnt/<drive>/... in common text-config files under $1.
xlate_paths() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -type f \( \
       -name '*.json' -o -name '*.jsonl' -o -name '*.toml' \
    -o -name '*.md'   -o -name '*.txt'   -o -name '*.yaml' -o -name '*.yml' \
  \) -exec perl -i -pe '
    s{([A-Za-z]):[\\/]+([^\s"\047]*)}{
      my $drive = lc $1;
      my $rest  = $2;
      $rest =~ s|\\+|/|g;
      $rest =~ s|/+|/|g;
      $rest =~ s|^/+||;
      "/mnt/" . $drive . "/" . $rest
    }ge
  ' {} +
}

# ---------------------------------------------------------------------------
# 1) zsh
# ---------------------------------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
  log "zsh already installed ($(zsh --version | head -n1))"
else
  log "installing zsh"
  sudo apt-get update
  sudo apt-get install -y zsh
fi

# ---------------------------------------------------------------------------
# 2) ensure ~/.zshrc exists
# ---------------------------------------------------------------------------
if [[ ! -f "$HOME/.zshrc" ]]; then
  log "creating ~/.zshrc"
  : > "$HOME/.zshrc"
fi

# ---------------------------------------------------------------------------
# 3) managed blocks in ~/.zshrc
# ---------------------------------------------------------------------------
upsert_block "$HOME/.zshrc" \
  '# >>> dotfiles: ported from .bashrc >>>' \
  '# <<< dotfiles: ported from .bashrc <<<' \
  "$(cat <<'EOF'
# >>> dotfiles: ported from .bashrc >>>
# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# nvs
export NVS_HOME="$HOME/.nvs"
[ -s "$NVS_HOME/nvs.sh" ] && . "$NVS_HOME/nvs.sh"

# local bin
export PATH="$HOME/.local/bin:$PATH"

# mise (zsh activation)
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
# <<< dotfiles: ported from .bashrc <<<
EOF
)"

upsert_block "$HOME/.zshrc" \
  '# >>> dotfiles: prompt + zoxide >>>' \
  '# <<< dotfiles: prompt + zoxide <<<' \
  "$(cat <<'EOF'
# >>> dotfiles: prompt + zoxide >>>
PROMPT='%F{cyan}%30<..<%1~%<<%f %# '

# zoxide — `z <substr>` to jump to a frecent dir
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
# <<< dotfiles: prompt + zoxide <<<
EOF
)"

upsert_block "$HOME/.zshrc" \
  '# >>> dotfiles: aliases >>>' \
  '# <<< dotfiles: aliases <<<' \
  "$(cat <<EOF
# >>> dotfiles: aliases >>>
DOTFILES_ALIASES="$ALIASES_DIR"
if [[ -d "\$DOTFILES_ALIASES" ]]; then
  setopt BASH_REMATCH 2>/dev/null   # so \$BASH_REMATCH in sourced bash files works
  for f in "\$DOTFILES_ALIASES"/*.sh(N); do
    [[ -r "\$f" ]] && source "\$f"
  done
fi
# <<< dotfiles: aliases <<<
EOF
)"

# ---------------------------------------------------------------------------
# 4) optional: make zsh the default login shell
# ---------------------------------------------------------------------------
current_shell=$(getent passwd "$USER" | cut -d: -f7 || true)
zsh_path=$(command -v zsh)
if [[ "$current_shell" == "$zsh_path" || "$current_shell" == */zsh ]]; then
  log "zsh is already the default shell ($current_shell)"
elif prompt_yn "Make zsh your default login shell (chsh -s $zsh_path)?"; then
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    log "warning: $zsh_path not listed in /etc/shells; chsh may refuse"
  fi
  log "running chsh (you'll be prompted for your WSL password)"
  if chsh -s "$zsh_path"; then
    log "default shell changed; run 'wsl --shutdown' from PowerShell, then reopen WSL"
  else
    log "chsh failed; you can retry manually: chsh -s $zsh_path"
  fi
else
  log "skipping default-shell change"
fi

# ---------------------------------------------------------------------------
# 5) zoxide (pinned to a vetted version)
# ---------------------------------------------------------------------------
# v0.9.9 released 2026-01-31; no advisories on GitHub Security Advisories or OSV.dev
# as of 2026-05-14. Bump intentionally — keep the version pinned for supply-chain safety.
ZOXIDE_VERSION="0.9.9"
case "$(uname -m)" in
  x86_64)  zoxide_arch="x86_64-unknown-linux-musl" ;;
  aarch64) zoxide_arch="aarch64-unknown-linux-musl" ;;
  *)       log "unsupported arch $(uname -m); skipping zoxide install"
           zoxide_arch="" ;;
esac

if [[ -n "$zoxide_arch" ]]; then
  if command -v zoxide >/dev/null 2>&1 \
     && zoxide --version 2>/dev/null | grep -qF "$ZOXIDE_VERSION"; then
    log "zoxide $ZOXIDE_VERSION already installed"
  else
    log "installing zoxide $ZOXIDE_VERSION"
    tmpdir=$(mktemp -d)
    url="https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${zoxide_arch}.tar.gz"
    if curl -fsSL "$url" -o "$tmpdir/zoxide.tar.gz" \
       && tar -xzf "$tmpdir/zoxide.tar.gz" -C "$tmpdir"; then
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$tmpdir/zoxide" "$HOME/.local/bin/zoxide"
      log "zoxide installed to $HOME/.local/bin/zoxide"
    else
      log "zoxide download/extract failed; skipping"
    fi
    rm -rf "$tmpdir"
  fi
fi

# ---------------------------------------------------------------------------
# 6) optional: sync SSH from Windows
# ---------------------------------------------------------------------------
if prompt_yn "Sync SSH settings from Windows ~/.ssh into WSL?"; then
  if win_home=$(resolve_win_home); then
    win_ssh="$win_home/.ssh"
    if [[ ! -d "$win_ssh" ]]; then
      log "Windows ~/.ssh ($win_ssh) not found; skipping SSH sync"
    else
      log "copying $win_ssh -> $HOME/.ssh"
      mkdir -p "$HOME/.ssh"
      cp -a "$win_ssh"/. "$HOME/.ssh"/

      # WSL-format: strip CRLF from copied files (keys, config, known_hosts)
      find "$HOME/.ssh" -maxdepth 1 -type f -exec sed -i 's/\r$//' {} +

      # permissions
      chmod 700 "$HOME/.ssh"
      find "$HOME/.ssh" -maxdepth 1 -type f -exec chmod 600 {} +
      find "$HOME/.ssh" -maxdepth 1 -type f -name '*.pub' -exec chmod 644 {} +
      [[ -f "$HOME/.ssh/known_hosts" ]] && chmod 644 "$HOME/.ssh/known_hosts"

      log "testing GitHub SSH (ssh -T git@github.com)"
      set +e
      ssh -T -o StrictHostKeyChecking=accept-new git@github.com
      rc=$?
      set -e
      log "ssh -T exited with $rc (GitHub returns 1 on success — look for 'Hi <user>!' above)"
    fi
  fi
else
  log "skipping SSH sync"
fi

# ---------------------------------------------------------------------------
# 7) optional: sync Claude settings from Windows
# ---------------------------------------------------------------------------
if prompt_yn "Sync Claude settings from Windows ~/.claude into WSL?"; then
  if win_home=$(resolve_win_home); then
    win_claude="$win_home/.claude"
    if [[ ! -d "$win_claude" ]]; then
      log "Windows ~/.claude ($win_claude) not found; skipping Claude sync"
    else
      mkdir -p "$HOME/.claude"
      for item in settings.json CLAUDE.md skills agents commands hooks output-styles keybindings.json; do
        copy_item "$win_claude/$item" "$HOME/.claude/$item"
      done
      log "translating Windows paths under ~/.claude"
      xlate_paths "$HOME/.claude"
      log "Claude settings synced"
    fi
  fi
else
  log "skipping Claude sync"
fi

# ---------------------------------------------------------------------------
# 8) optional: sync Codex settings from Windows
# ---------------------------------------------------------------------------
if prompt_yn "Sync Codex settings from Windows ~/.codex into WSL?"; then
  if win_home=$(resolve_win_home); then
    win_codex="$win_home/.codex"
    if [[ ! -d "$win_codex" ]]; then
      log "Windows ~/.codex ($win_codex) not found; skipping Codex sync"
    else
      mkdir -p "$HOME/.codex"
      for item in config.toml AGENTS.md skills rules prompts memories; do
        copy_item "$win_codex/$item" "$HOME/.codex/$item"
      done
      log "translating Windows paths under ~/.codex"
      xlate_paths "$HOME/.codex"
      log "Codex settings synced"
    fi
  fi
else
  log "skipping Codex sync"
fi

# ---------------------------------------------------------------------------
# 9) optional: copy ~/.gitconfig from repo (translate Windows paths to /mnt/<drive>/)
# ---------------------------------------------------------------------------
if prompt_yn "Copy $SCRIPT_DIR/common/.gitconfig to ~/.gitconfig (translating Windows paths)?"; then
  gitconfig_src="$SCRIPT_DIR/common/.gitconfig"
  gitconfig_dst="$HOME/.gitconfig"
  if [[ ! -f "$gitconfig_src" ]]; then
    log "source $gitconfig_src not found; skipping git config copy"
  else
    if [[ -e "$gitconfig_dst" || -L "$gitconfig_dst" ]]; then
      backup="$gitconfig_dst.bak.$(date +%Y%m%d%H%M%S)"
      log "backing up existing $gitconfig_dst -> $backup"
      mv "$gitconfig_dst" "$backup"
    fi
    cp "$gitconfig_src" "$gitconfig_dst"
    log "translating Windows paths in $gitconfig_dst"
    # Match drive letter + colon + one-or-more `\\segment` (segments may contain
    # spaces; they end at `\`, `"`, or newline). Rewrite to /mnt/<drive>/...
    perl -i -pe '
      s{([A-Za-z]):((?:\\\\[^\\"\n]+)+)}{
        my $drive = lc $1;
        my $rest = $2;
        $rest =~ s|\\\\|/|g;
        "/mnt/$drive$rest"
      }ge;
    ' "$gitconfig_dst"
    log "copied $gitconfig_src -> $gitconfig_dst"
  fi
else
  log "skipping git config copy"
fi

log "done."
log "if default shell changed: run 'wsl --shutdown' from PowerShell, then reopen WSL"
