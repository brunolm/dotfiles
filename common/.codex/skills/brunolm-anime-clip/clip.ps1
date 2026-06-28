#requires -Version 7
<#
.SYNOPSIS
  Cut an optimized, subtitle-burned clip from an anime episode and report the
  in-window dialogue lines as JSON (for the skill to turn into JP + romaji).

.DESCRIPTION
  Deterministic media half of the `brunolm-anime-clip` skill. Resolves the
  Japanese audio track and the "Full Subtitles" track (or an external sub file),
  time-shifts the subtitle + embedded fonts to a 0-based window, frame-accurately
  cuts the range, burns the subs in, and writes an H.265 (default) or H.264 MP4
  to the output folder. Finally prints a JSON block (between markers) with the
  output metadata and the dialogue lines inside the window.

  All temp work happens under -WorkDir; ffmpeg is invoked with that as the CWD so
  the libass `subtitles` filter only ever sees the relative names `subs.ass` /
  `fonts`, sidestepping Windows drive-colon escaping in filtergraphs.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Video,
  [Parameter(Mandatory)][string]$Start,
  [Parameter(Mandatory)][string]$End,
  [string]$SubtitleSource,
  [string]$OutDir = (Join-Path $env:USERPROFILE 'Downloads'),
  [ValidateSet('h265','h264')][string]$Codec = 'h265',
  [int]$Crf = -1,
  [string]$Preset = 'slow',
  [string]$AudioLang = 'jpn',
  [int]$AudioBitrateK = 160,
  [string]$WorkDir = (Join-Path $env:TEMP 'brunolm-anime-clip')
)

$ErrorActionPreference = 'Stop'

# ---------- helpers ----------
function To-Seconds([string]$t) {
  if (-not $t) { return 0.0 }
  $t = $t.Trim() -replace ',', '.'
  $parts = $t -split ':'
  switch ($parts.Count) { 1 { $mult = @(1) } 2 { $mult = @(60,1) } 3 { $mult = @(3600,60,1) } default { return 0.0 } }
  $sum = 0.0
  for ($i = 0; $i -lt $parts.Count; $i++) {
    $v = 0.0
    [void][double]::TryParse($parts[$i], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)
    $sum += $v * $mult[$i]
  }
  return $sum
}

function Clean-AssText([string]$s) {
  if (-not $s) { return '' }
  $s = $s -replace '\{[^}]*\}', ''                 # {\override} / drawing blocks
  $s = $s -replace '\\N', ' ' -replace '\\n', ' ' -replace '\\h', ' '
  return ($s -replace '\s+', ' ').Trim()
}

function Get-Dialogues([string]$path, [double]$dur) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $out = @()
  foreach ($line in (Get-Content -LiteralPath $path)) {
    if ($line -notlike 'Dialogue:*') { continue }
    $p = $line -split ',', 10
    if ($p.Count -lt 10) { continue }
    $s = To-Seconds $p[1]; $e = To-Seconds $p[2]
    if ($s -lt $dur -and $e -gt 0) {                # overlaps the [0,dur] window
      $text = Clean-AssText $p[9]
      if ($text) {
        $out += [pscustomobject]@{ start = $p[1].Trim(); end = $p[2].Trim(); startSec = [math]::Round($s,2); style = $p[3].Trim(); text = $text }
      }
    }
  }
  return ($out | Sort-Object startSec)
}

function Invoke-Ffmpeg([string[]]$ffArgs) {
  & ffmpeg @ffArgs
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed ($LASTEXITCODE): ffmpeg $($ffArgs -join ' ')" }
}

# ---------- resolve inputs ----------
if (-not (Test-Path -LiteralPath $Video)) { throw "Video not found: $Video" }
$Video = (Resolve-Path -LiteralPath $Video).Path
$base  = [System.IO.Path]::GetFileNameWithoutExtension($Video)

$startSec = To-Seconds $Start
$endSec   = To-Seconds $End
$dur = [math]::Round($endSec - $startSec, 3)
if ($dur -le 0) { throw "End ($End) must be after start ($Start)." }
$ssArg = ('{0:0.###}' -f $startSec)
$tArg  = ('{0:0.###}' -f $dur)

if ($Crf -lt 0) { $Crf = if ($Codec -eq 'h265') { 26 } else { 21 } }

# ---------- probe streams ----------
$probe = (& ffprobe -v error -print_format json -show_streams -show_format $Video | ConvertFrom-Json)
$audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })
$subs  = @($probe.streams | Where-Object { $_.codec_type -eq 'subtitle' })
if ($audio.Count -eq 0) { throw "No audio streams in: $Video" }

# audio: first track whose language == $AudioLang, else first track
$audioRel = 0; $audioNote = ''
$foundLang = $false
for ($i = 0; $i -lt $audio.Count; $i++) {
  if ($audio[$i].tags.language -eq $AudioLang) { $audioRel = $i; $foundLang = $true; break }
}
if (-not $foundLang) { $audioNote = "No '$AudioLang' audio track found; used first audio track ($($audio[0].tags.language))." }

# ---------- prepare work dir ----------
$workSubs = Join-Path $WorkDir 'subs.ass'
$fontsDir = Join-Path $WorkDir 'fonts'
Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

# ---------- resolve subtitle source -> 0-based subs.ass ----------
$burnSub = $false
$subDesc = ''
$externalSub = $null

if ($SubtitleSource) {
  if (Test-Path -LiteralPath $SubtitleSource -PathType Leaf) {
    $externalSub = (Resolve-Path -LiteralPath $SubtitleSource).Path
  }
  elseif (Test-Path -LiteralPath $SubtitleSource -PathType Container) {
    $epTag = if ($base -match '(?i)(S\d{1,2}E\d{1,3})') { $matches[1] } else { '' }
    $cands = Get-ChildItem -LiteralPath $SubtitleSource -Recurse -File |
      Where-Object { $_.Extension -in '.ass', '.ssa', '.srt' }
    if (-not $cands) { throw "No .ass/.ssa/.srt files under: $SubtitleSource" }
    $best = $cands | Sort-Object -Descending @{ Expression = {
        $s = 0
        if ($epTag -and $_.Name -match [regex]::Escape($epTag)) { $s += 100 }
        if ($_.Name -match '(?i)full')       { $s += 40 }
        if ($_.Name -match '(?i)sign|song')  { $s -= 100 }
        if ($_.Name -match '(?i)\beng?\b|english') { $s += 20 }
        if ($_.Extension -in '.ass', '.ssa') { $s += 10 }
        $s } } | Select-Object -First 1
    $externalSub = $best.FullName
  }
  else { throw "Subtitle source not found: $SubtitleSource" }
}

if ($externalSub) {
  Invoke-Ffmpeg @('-y','-hide_banner','-loglevel','error','-ss',$ssArg,'-t',$tArg,'-i',$externalSub,$workSubs)
  $burnSub = $true
  $subDesc = "external: $externalSub"
}
elseif ($subs.Count -gt 0) {
  # pick embedded text sub: prefer "Full", avoid signs/songs, prefer english + ass
  $subRel = -1; $bestScore = [int]::MinValue; $bestTitle = ''
  for ($i = 0; $i -lt $subs.Count; $i++) {
    $st = $subs[$i]
    $title = "$($st.tags.title)"; $lang = "$($st.tags.language)"
    $s = 0
    if ($title -match '(?i)full') { $s += 100 }
    if ($title -match '(?i)sign|song') { $s -= 100 }
    if ($lang -eq 'eng') { $s += 50 }
    if ($st.codec_name -in 'ass','ssa') { $s += 10 }
    if ($s -gt $bestScore) { $bestScore = $s; $subRel = $i; $bestTitle = $title }
  }
  if ($subRel -ge 0) {
    Invoke-Ffmpeg @('-y','-hide_banner','-loglevel','error','-ss',$ssArg,'-t',$tArg,'-i',$Video,'-map',"0:s:$subRel",$workSubs)
    $burnSub = $true
    $subDesc = "embedded #$subRel" + ($(if ($bestTitle) { " ($bestTitle)" } else { '' }))
  }
}
if (-not $burnSub) { $subDesc = 'none (no subtitle source found; clip rendered without burned subtitles)' }

# ---------- dump embedded fonts (best effort) ----------
Push-Location $fontsDir
try { & ffmpeg -y -hide_banner -loglevel error -dump_attachment:t '' -i $Video *> $null } catch { }
Pop-Location
$global:LASTEXITCODE = 0   # the bulk attachment dump exits non-zero by design

# ---------- encode ----------
$startFmt = $Start.Trim() -replace ':', '.'
$endFmt   = $End.Trim()   -replace ':', '.'
$suffix   = if ($Codec -eq 'h265') { ' [h265]' } else { ' [h264]' }
$outName  = "$base - clip ($startFmt-$endFmt)$suffix.mp4"
$out      = Join-Path $OutDir $outName
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$vcodec = if ($Codec -eq 'h265') { @('-c:v','libx265','-tag:v','hvc1') } else { @('-c:v','libx264') }
$ffArgs = @('-y','-hide_banner','-loglevel','error','-ss',$ssArg,'-t',$tArg,'-i',$Video,'-map','0:v:0','-map',"0:a:$audioRel")
if ($burnSub) { $ffArgs += @('-vf','subtitles=subs.ass:fontsdir=fonts') }
$ffArgs += $vcodec
$ffArgs += @('-crf',"$Crf",'-preset',$Preset,'-pix_fmt','yuv420p','-c:a','aac','-b:a',"${AudioBitrateK}k",'-ac','2','-dn','-map_chapters','-1','-movflags','+faststart',$out)

Push-Location $WorkDir
try { Invoke-Ffmpeg $ffArgs } finally { Pop-Location }

# ---------- collect dialogue + optional Japanese source ----------
$burnedLines = if ($burnSub) { @(Get-Dialogues $workSubs $dur) } else { @() }

$japaneseLines = @()
$jpRel = -1
for ($i = 0; $i -lt $subs.Count; $i++) { if ($subs[$i].tags.language -eq 'jpn') { $jpRel = $i; break } }
if ($jpRel -ge 0) {
  $jpPath = Join-Path $WorkDir 'subs_jp.ass'
  Invoke-Ffmpeg @('-y','-hide_banner','-loglevel','error','-ss',$ssArg,'-t',$tArg,'-i',$Video,'-map',"0:s:$jpRel",$jpPath)
  $japaneseLines = @(Get-Dialogues $jpPath $dur)
}

# ---------- result JSON ----------
$durOut = 0.0
[void][double]::TryParse((& ffprobe -v error -show_entries format=duration -of csv=p=0 $out), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$durOut)

$result = [pscustomobject]@{
  output            = $out
  sizeMB            = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 2)
  durationSec       = [math]::Round($durOut, 2)
  requestedStart    = $Start
  requestedEnd      = $End
  codec             = $Codec
  crf               = $Crf
  preset            = $Preset
  audioTrack        = $AudioLang
  audioNote         = $audioNote
  subtitleSource    = $subDesc
  hasJapaneseSource = ($japaneseLines.Count -gt 0)
  burnedLines       = $burnedLines
  japaneseLines     = $japaneseLines
}

Write-Output '===BRUNOLM_ANIME_CLIP_JSON==='
$result | ConvertTo-Json -Depth 6
Write-Output '===END_BRUNOLM_ANIME_CLIP_JSON==='
