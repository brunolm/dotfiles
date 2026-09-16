#requires -Version 5.1

# Handler for the claude-focus: URI that the stop-hook toast launches. Any process or web page can
# invoke a registered protocol, so the URI is only ever read as the id of a process to focus.

param([string]$Uri)

function Get-MainWindowHandle {
  param([int]$ProcessId)

  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if (-not $process) { return [IntPtr]::Zero }
  return $process.MainWindowHandle
}

function Set-Foreground {
  param([IntPtr]$Handle)

  if (-not ('Dotfiles.Focus' -as [type])) {
    Add-Type -Namespace Dotfiles -Name Focus -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
'@
  }

  $SW_RESTORE = 9
  if ([Dotfiles.Focus]::IsIconic($Handle)) { [Dotfiles.Focus]::ShowWindow($Handle, $SW_RESTORE) | Out-Null }

  # Windows only honours this for a process the user just launched, which is what clicking the toast
  # does. Nothing else raises a window from here: AttachThreadInput and SwitchToThisWindow are both
  # refused as well once that grant is gone.
  [Dotfiles.Focus]::SetForegroundWindow($Handle) | Out-Null
}

try {
  # The shell may normalize the opaque URI with a trailing slash.
  if ($Uri -notmatch '^claude-focus:(\d+)/?$') { return }

  $handle = Get-MainWindowHandle ([int]$Matches[1])
  if ($handle -eq [IntPtr]::Zero) { return }

  Set-Foreground $handle
} catch {
}
