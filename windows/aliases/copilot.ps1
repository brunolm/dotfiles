## Start-Copilot: launches copilot with --allow-tool flags from Claude Code settings
function Start-Copilot {
  $settingsPath = "$env:USERPROFILE\.claude\settings.json"
  $args_ = @()

  if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $allowList = $settings.permissions.allow

    foreach ($entry in $allowList) {
      if ($entry -match '^Bash\((.+)\)$') {
        $cmd = $Matches[1]
        $args_ += "--allow-tool=shell($cmd)"
      }
      elseif ($entry -match '^WebFetch\(domain:(.+)\)$') {
        $args_ += "--allow-url=$($Matches[1])"
      }
    }
  }

  & copilot @args_ @args
}
