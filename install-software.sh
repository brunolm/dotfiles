#!/usr/bin/env bash
# Install software for WSL/Ubuntu. Mirrors install-software.ps1.
# Run: bash install-software.sh

set -euo pipefail

# The mise and Claude Code installers put their binaries in ~/.local/bin.
export PATH="$HOME/.local/bin:$PATH"

install_software() {
  sudo apt update

  sudo apt install -y git
  sudo apt install -y gnupg
  sudo apt install -y ffmpeg
  sudo apt install -y imagemagick
  # C toolchain: rust (from mise) needs a linker, as do native npm modules.
  sudo apt install -y build-essential

  install_mise
  install_claude

  # GUI / productivity apps. On WSL these run via WSLg; usually you'd
  # install them on the Windows host instead. Uncomment to install on
  # the Linux side.

  # sudo snap install slack --classic
  # sudo snap install obs-studio
  # whatsapp: no first-party Linux client; use the web app.
  # copyq: apt ships an old build; grab the AppImage from
  #   https://github.com/hluk/CopyQ/releases

  # Gaming
  # sudo snap install discord
  # sudo apt install -y steam

  # sudo apt install -y docker.io   # equivalent to docker-desktop on Linux

  # sudo npm install -g vercel

  # Windows-only on the original list, no Linux port:
  #   powertoys, autohotkey, sharex
}

# Installing mise is only half the job: the toolchains in ~/.config/mise/config.toml (linked by
# install.sh) are what put node/npm/bun on the PATH.
install_mise() {
  if command -v mise >/dev/null 2>&1; then
    mise self-update -y
  else
    curl -fsSL https://mise.run | sh
  fi
  mise install
}

# The native installer is also the updater: rerunning it replaces the binary in ~/.local/bin.
install_claude() {
  if command -v claude >/dev/null 2>&1; then
    claude update
    return
  fi
  curl -fsSL https://claude.ai/install.sh | bash
}

install_software

# Snap is required for the snap installs above. If missing:
#   sudo apt install -y snapd
