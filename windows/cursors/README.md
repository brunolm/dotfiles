# Custom cursors

Crystal-style Windows 11 cursor scheme ("BrunoLM"), installed automatically
by the root `install.ps1`. White faceted gem pointer with a breathing aura
wave, ice-blue accents, and a Windows-style blue spinner for the busy
cursors. Comes with a companion click effect.

## Layout

- `brunolm/` — the cursor files. One `.cur` (static) or `.ani` (animated) per
  role, named after the role: `arrow`, `help`, `appstarting`, `wait`,
  `crosshair`, `ibeam`, `nwpen`, `no`, `sizens`, `sizewe`, `sizenwse`,
  `sizenesw`, `sizeall`, `uparrow`, `hand`, `person`, `pin`. If both
  extensions exist for a role, `.ani` wins; a missing role falls back to
  `arrow.cur`.
- `install-cursors.ps1` — copies the cursors to
  `%LOCALAPPDATA%\Microsoft\Windows\Cursors\BrunoLM`, registers the scheme in
  the registry, and applies it live.
- `click-sparkle/` — companion click effect (a small soft ring pulse on every
  left click). `install-click-sparkle.ps1` compiles `ClickSparkle.cs` with
  Windows' bundled csc.exe, registers it under HKCU Run, and starts it.

## Reverting

Cursors: Settings → Bluetooth & devices → Mouse → Additional mouse settings →
Pointers → pick the "Windows Default" scheme.

Click effect: `Stop-Process -Name ClickSparkle` and delete the `ClickSparkle`
value under `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`.
