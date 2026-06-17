#requires -Version 5.1

# Native Windows toast (no third-party modules). A notification failure must never
# disrupt the Claude session, so any error is swallowed and we exit cleanly.

function Get-LastUserText {
  param([string]$TranscriptPath)

  if (-not $TranscriptPath -or -not (Test-Path -LiteralPath $TranscriptPath)) { return $null }

  # Transcript is JSONL (one entry per line); scan from the end for the latest user turn.
  $lines = Get-Content -LiteralPath $TranscriptPath -ErrorAction Stop
  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    $entry = $null
    try { $entry = $lines[$i] | ConvertFrom-Json } catch { continue }
    if ($entry.type -ne 'user') { continue }

    $content = $entry.message.content
    if ($content -is [string]) { return $content }

    # content can be an array of blocks; keep only the text ones.
    $text = ($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' '
    if ($text) { return $text }
  }
  return $null
}

function Get-Slice {
  param([string]$Text, [int]$Max = 100)

  if (-not $Text) { return 'Finished responding.' }
  $oneLine = ($Text -replace '\s+', ' ').Trim()
  if ($oneLine.Length -le $Max) { return $oneLine }
  return $oneLine.Substring(0, $Max) + [char]0x2026
}

try {
  # Hook payload arrives as JSON on stdin; guard against interactive runs with no pipe.
  $payload = $null
  if ([Console]::IsInputRedirected) {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $payload = $raw | ConvertFrom-Json }
  }

  $sessionId = if ($payload.session_id) { $payload.session_id } else { 'unknown session' }
  $cwd = if ($payload.cwd) { $payload.cwd } else { '(no cwd)' }
  $slice = Get-Slice (Get-LastUserText $payload.transcript_path)

  # WinRT projections only surface when loaded with the ContentType=WindowsRuntime
  # assembly hint; a plain Add-Type / using statement won't expose these types.
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

  # Toasts only render under a registered AppUserModelID. Reuse the AppID baked into
  # the built-in Windows PowerShell Start-menu shortcut so nothing has to be registered.
  $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

  # ToastGeneric (vs the legacy ToastTextNN templates) is the only binding that fits a
  # title plus three body lines. The slice is arbitrary user text, so each value is
  # XML-escaped before interpolation or a stray < / & would corrupt the document.
  $xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>Claude Code</text>
      <text>$([System.Security.SecurityElement]::Escape($slice))</text>
      <text>$([System.Security.SecurityElement]::Escape($cwd))</text>
      <text>$([System.Security.SecurityElement]::Escape($sessionId))</text>
    </binding>
  </visual>
</toast>
"@

  $doc = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]::new()
  $doc.LoadXml($xml)

  $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} catch {
}
