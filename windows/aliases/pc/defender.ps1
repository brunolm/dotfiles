function B-PC-Disable-RealtimeProtection() {
  Set-MpPreference -DisableRealtimeMonitoring $true
}

## B-PC-Add-DefenderExclusions: excludes the C: and P: drives, the rust/bun/node/python/dotnet/go/C++ toolchains and the VS Code Insiders, Claude, Grok and Codex processes from Defender scanning (needs an elevated shell)
function B-PC-Add-DefenderExclusions([switch]$DryRun) {
  if (!$DryRun -and !(B-PC-IsElevated)) {
    Write-Error "Run from an elevated shell; Add-MpPreference needs admin."
    return
  }

  $preference = Get-MpPreference
  PCDefender-AddMissing 'path' @($preference.ExclusionPath) (PCDefender-ExcludedPaths) $DryRun {
    param($value) Add-MpPreference -ExclusionPath $value
  }
  PCDefender-AddMissing 'process' @($preference.ExclusionProcess) (PCDefender-ExcludedProcesses) $DryRun {
    param($value) Add-MpPreference -ExclusionProcess $value
  }
}

function PCDefender-AddMissing($kind, $existing, $wanted, $dryRun, $add) {
  foreach ($value in $wanted) {
    if ($existing -contains $value) {
      Write-Host ("  {0,-8} {1,-22} already excluded" -f $kind, $value) -ForegroundColor DarkGray
      continue
    }
    if ($dryRun) {
      Write-Host ("  {0,-8} {1,-22} would be excluded" -f $kind, $value) -ForegroundColor Yellow
      continue
    }
    & $add $value
    Write-Host ("  {0,-8} {1,-22} excluded" -f $kind, $value) -ForegroundColor Green
  }
}

# Whole drives: everything under them is skipped by real-time and scheduled scans.
function PCDefender-ExcludedPaths() {
  return @('C:\', 'P:\')
}

# Files opened by these processes are not scanned; Defender matches on the image name.
function PCDefender-ExcludedProcesses() {
  return @(
    'rustc.exe', 'cargo.exe', 'rust-analyzer.exe',
    'bun.exe',
    'node.exe',
    'python.exe', 'pythonw.exe',
    'dotnet.exe', 'MSBuild.exe', 'VBCSCompiler.exe',
    'go.exe', 'gopls.exe',
    'cl.exe', 'link.exe', 'clang.exe', 'clang++.exe', 'clang-cl.exe', 'gcc.exe', 'g++.exe', 'ld.exe', 'ninja.exe', 'cmake.exe', 'make.exe', 'mingw32-make.exe',
    'Code - Insiders.exe',
    'claude.exe',
    'grok.exe', 'agent.exe',
    'codex.exe', 'codex-command-runner.exe', 'codex-code-mode-host.exe'
  )
}
