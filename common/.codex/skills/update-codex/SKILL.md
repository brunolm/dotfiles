---
name: update-codex
description: Use this skill when the user asks to update Codex, upgrade the OpenAI Codex CLI, or refresh the Codex binaries. Runs `npm i -g @openai/codex`, copies the bundled .exe files from the global node_modules vendor directory into `C:\Users\bruno\.local\bin`, then verifies with `codex --version`.
version: 1.0.0
allowed-tools:
  - Bash(npm i -g @openai/codex:*)
  - Bash(npm config get prefix:*)
  - Bash(codex --version:*)
  - PowerShell
  - Read
  - Glob
---

# Update Codex

Update the OpenAI Codex CLI and refresh the local binaries used from `C:\Users\bruno\.local\bin`.

## Steps

1. **Install / upgrade Codex globally**

   ```powershell
   npm i -g @openai/codex
   ```

2. **Find the npm global prefix**

   ```powershell
   npm config get prefix
   ```

   Use the returned path as `<prefix>` below.

3. **Copy the vendored .exe files into `C:\Users\bruno\.local\bin`**

   Source folders (both):
   - `<prefix>\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex`
   - `<prefix>\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\path`

   Destination: `C:\Users\bruno\.local\bin`

   PowerShell:

   ```powershell
   $prefix = (npm config get prefix).Trim()
   $dest = 'C:\Users\bruno\.local\bin'
   $base = Join-Path $prefix 'node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc'
   $sources = @(
       (Join-Path $base 'codex'),
       (Join-Path $base 'path')
   )
   New-Item -ItemType Directory -Force -Path $dest | Out-Null
   foreach ($src in $sources) {
       Get-ChildItem -Path $src -Filter *.exe -File | Copy-Item -Destination $dest -Force
   }
   ```

4. **Verify the install**

   ```powershell
   codex --version
   ```

5. **Print a short summary**

   - Installed version (from `npm i -g` output, if visible)
   - npm prefix used
   - List of .exe files copied (name + destination)
   - Output of `codex --version`

## Note: Codex updating itself

If you (the assistant) are **Codex** running this skill against itself, the binaries you are currently executing live in the destination folder and cannot be overwritten while in use. In that case:

- **Do not** run steps 3 and 4 yourself.
- Instead, output a single PowerShell script block the user can paste into a separate PowerShell window to perform the copy and the version check. Use the script from step 3 above, followed by `codex --version`. Tell the user to run it after the current Codex process has exited.

For Claude Code (or any non-Codex assistant), run all five steps normally.
