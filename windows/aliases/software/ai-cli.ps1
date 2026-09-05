# The native installer is also the updater: rerunning it replaces the binary in ~\.local\bin.
function B-Software-Update-Claude() {
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude update
    return
  }
  Write-Host "Installing Claude Code..." -ForegroundColor Cyan
  irm https://claude.ai/install.ps1 | iex
}

function B-Software-Update-Grok() {
  if (Get-Command grok -ErrorAction SilentlyContinue) {
    grok update
    return
  }
  Write-Host "Installing Grok CLI..." -ForegroundColor Cyan
  irm https://x.ai/cli/install.ps1 | iex
}

# npm installs the package, but the launcher it puts on PATH is a .ps1 shim running under
# node; the native exes are vendored inside the package and copied to ~\.local\bin so
# `codex` starts without node. Codex moves them between subfolders across releases, so every
# exe under the vendor folder is swept.
function B-Software-Update-Codex() {
  if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "npm not found; install node through mise (mise install) and open a new shell first."
    return
  }

  npm install -g @openai/codex
  $prefix = (npm config get prefix).Trim()
  $vendor = Join-Path $prefix 'node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc'
  if (!(Test-Path -LiteralPath $vendor)) {
    Write-Error "Codex vendor folder not found at $vendor"
    return
  }

  $dest = Join-Path $HOME '.local\bin'
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  foreach ($exe in Get-ChildItem -LiteralPath $vendor -Recurse -Filter *.exe -File) {
    Copy-Item -LiteralPath $exe.FullName -Destination $dest -Force
    Write-Host "  copied $($exe.Name)" -ForegroundColor DarkGray
  }
  codex --version
}
