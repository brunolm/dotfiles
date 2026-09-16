#requires -Version 5.1

# Native Windows toast (no third-party modules). A notification failure must never
# disrupt the Claude session, so any error is swallowed and we exit cleanly.

function Get-TurnText {
  param([string]$TranscriptPath)

  if (-not $TranscriptPath) { return $null }
  $file = Get-Item -LiteralPath $TranscriptPath -ErrorAction SilentlyContinue
  if (-not $file) { return $null }

  # The wider window is a fallback for turns whose tool results are large enough to push the user
  # message out of the first slice.
  $turn = $null
  foreach ($window in 512KB, 8MB) {
    $turn = Find-TurnText (Get-TranscriptTail $file $window)
    if ($turn.User -or $window -ge $file.Length) { break }
  }
  return $turn
}

# Transcripts grow into the tens of megabytes and this runs on every turn, so only the tail is read.
function Get-TranscriptTail {
  param([System.IO.FileInfo]$File, [int]$MaxBytes)

  $offset = [Math]::Max(0, $File.Length - $MaxBytes)

  # Claude is still appending to the transcript, so the share mode has to allow its writes.
  $stream = [System.IO.File]::Open($File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $stream.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $lines = $reader.ReadToEnd() -split "`n"
  } finally {
    $stream.Dispose()
  }

  # A non-zero offset lands mid-line, and that fragment is not valid JSON.
  if ($offset -gt 0 -and $lines.Count) { return $lines[1..($lines.Count - 1)] }
  return $lines
}

# Transcript is JSONL (one entry per line); scan from the end for the last prompt and the reply that
# followed it. Entries that carry no text of their own — tool calls and their results — are skipped,
# as are subagent turns, which belong to a nested conversation rather than this one.
function Find-TurnText {
  param([string[]]$Lines)

  $user = $null
  $assistant = $null
  for ($i = $Lines.Count - 1; $i -ge 0; $i--) {
    $entry = $null
    try { $entry = $Lines[$i] | ConvertFrom-Json } catch { continue }
    if ($entry.isSidechain -or ($entry.type -ne 'user' -and $entry.type -ne 'assistant')) { continue }

    $text = Get-EntryText $entry
    if (-not $text) { continue }
    if ($entry.type -eq 'user') {
      $user = $text
      break
    }
    if (-not $assistant) { $assistant = $text }
  }

  return [pscustomobject]@{ User = $user; Assistant = $assistant }
}

function Get-EntryText {
  param($Entry)

  $content = $Entry.message.content
  if ($content -is [string]) { return $content }

  # content can be an array of blocks; keep only the text ones.
  return ($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' '
}

function Get-Slice {
  param([string]$Text, [int]$Max = 100)

  if (-not $Text) { return '' }
  $oneLine = ($Text -replace '\s+', ' ').Trim()
  if ($oneLine.Length -le $Max) { return $oneLine }
  return $oneLine.Substring(0, $Max) + [char]0x2026
}

# Clicking the toast has to name the window to raise, and a console app owns no window of its own:
# the nearest ancestor that has one is the terminal hosting the session. Each level up costs a WMI
# query, so the answer is kept for the rest of the session.
function Get-HostWindowPid {
  param([string]$SessionId, [int]$StartPid)

  $cache = Join-Path $env:TEMP ("claude-stop-notify-{0}.pid" -f ($SessionId -replace '[^A-Za-z0-9-]', '_'))
  $fields = (Get-Content -LiteralPath $cache -ErrorAction SilentlyContinue) -split ' '
  if ($fields.Count -eq 2 -and $fields[0] -match '^\d+$' -and $fields[1] -match '^\d+$') {
    $process = Get-Process -Id ([int]$fields[0]) -ErrorAction SilentlyContinue

    # PIDs are recycled and a resumed session can land in another terminal, so the start time has to
    # match as well. Reading it is denied for a process owned by another account.
    $ticks = if ($process) { try { $process.StartTime.Ticks } catch { 0 } } else { 0 }
    if ($ticks -eq [long]$fields[1]) { return [int]$fields[0] }
  }

  $found = Find-HostWindowPid $StartPid
  if (-not $found) { return $null }

  Set-Content -LiteralPath $cache -Value "$found $((Get-Process -Id $found).StartTime.Ticks)" -ErrorAction SilentlyContinue
  return $found
}

function Find-HostWindowPid {
  param([int]$StartPid, [int]$MaxDepth = 8)

  $current = $StartPid
  for ($i = 0; $i -lt $MaxDepth; $i++) {
    $parent = Get-ParentPid $current
    if (-not $parent) { return $null }

    $process = Get-Process -Id $parent -ErrorAction SilentlyContinue
    if (-not $process -or $process.Name -eq 'explorer') { return $null }
    if ($process.MainWindowHandle -ne [IntPtr]::Zero) { return $parent }

    $current = $parent
  }
  return $null
}

# Get-CimInstance and Get-WmiObject load a few hundred milliseconds of cmdlet machinery on first
# use, which a hook running once per turn would pay every time; the searcher they wrap does not.
function Get-ParentPid {
  param([int]$ProcessId)

  $searcher = New-Object System.Management.ManagementObjectSearcher("SELECT ParentProcessId FROM Win32_Process WHERE ProcessId=$ProcessId")
  try {
    foreach ($row in $searcher.Get()) { return [int]$row.ParentProcessId }
  } finally {
    $searcher.Dispose()
  }
  return 0
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
  $turn = Get-TurnText $payload.transcript_path
  $prompt = Get-Slice $turn.User
  if (-not $prompt) { $prompt = 'Finished responding.' }
  $answer = Get-Slice $turn.Assistant
  $hostPid = Get-HostWindowPid $sessionId $PID

  # WinRT projections only surface when loaded with the ContentType=WindowsRuntime
  # assembly hint; a plain Add-Type / using statement won't expose these types.
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

  # Toasts only render under a registered AppUserModelID; this one carries the Claude Code name and
  # icon, and B-Reg-Register-ClaudeToastAppId creates it.
  $appId = 'BrunoLM.ClaudeCode'

  # Protocol activation is the only kind a toast raised from a script can use — foreground and
  # background activation both need a COM activator that only a packaged app can register.
  # B-Reg-Register-ClaudeFocusProtocol registers the scheme.
  $activation = ''
  if ($hostPid) { $activation = " activationType=`"protocol`" launch=`"claude-focus:$hostPid`"" }

  # ToastGeneric renders three <text> elements at most: a title and two body lines. Each group past
  # them adds a line of its own, set off by the blank line that separates the prompt from the answer,
  # and group text needs hint-wrap to break instead of being clipped. The app name already sits in
  # the toast header, so the title carries the project. The slices are arbitrary text, so each value
  # is XML-escaped before interpolation or a stray < / & would corrupt the document.
  $project = Split-Path -Leaf $cwd
  $xml = @"
<toast$activation>
  <visual>
    <binding template="ToastGeneric">
      <text>$([System.Security.SecurityElement]::Escape($project))</text>
      <text>$([System.Security.SecurityElement]::Escape($prompt))</text>
      <group>
        <subgroup>
          <text hint-wrap="true" hint-maxLines="3">$([System.Security.SecurityElement]::Escape($answer))</text>
        </subgroup>
      </group>
      <group>
        <subgroup>
          <text hint-style="body">$([System.Security.SecurityElement]::Escape($cwd))</text>
        </subgroup>
      </group>
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
