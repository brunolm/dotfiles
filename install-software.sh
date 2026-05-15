#!/usr/bin/env bash
# Install software for WSL/Ubuntu. Mirrors install-software.ps1.
# Run: bash install-software.sh

set -euo pipefail

install_software() {
  sudo apt update

  sudo apt install -y git
  sudo apt install -y gnupg
  sudo apt install -y ffmpeg
  sudo apt install -y imagemagick

  # GUI / productivity apps. On WSL these run via WSLg; usually you'd
  # install them on the Windows host instead. Uncomment to install on
  # the Linux side.

  # sudo snap install slack --classic
  # sudo snap install obs-studio
  # whatsapp: no first-party Linux client; use the web app.

  # Gaming
  # sudo snap install discord
  # sudo apt install -y steam

  # sudo apt install -y docker.io   # equivalent to docker-desktop on Linux

  # sudo npm install -g vercel
  # sudo apt install -y vim

  # Windows-only on the original list, no Linux port:
  #   powertoys, autohotkey, ditto, sharex
}

install_software

# Snap is required for the snap installs above. If missing:
#   sudo apt install -y snapd
