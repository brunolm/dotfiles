# Compiles ClickSparkle.cs with the csc.exe bundled in Windows' .NET
# Framework (no SDK needed), installs it to LOCALAPPDATA, registers it to
# start with Windows, and (re)starts it.
$src = Join-Path $PSScriptRoot "ClickSparkle.cs"
$destDir = Join-Path $env:LOCALAPPDATA "BrunoLM\ClickSparkle"
$exe = Join-Path $destDir "ClickSparkle.exe"

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (!(Test-Path $csc)) {
  Write-Error "csc.exe not found at $csc"
  exit 1
}

New-Item -ItemType Directory -Force $destDir | Out-Null
Stop-Process -Name ClickSparkle -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

& $csc /nologo /target:winexe /out:$exe /r:System.Windows.Forms.dll /r:System.Drawing.dll $src
if ($LASTEXITCODE) {
  Write-Error "ClickSparkle compilation failed"
  exit 1
}

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ClickSparkle" -Value $exe
Start-Process $exe

Write-Host "ClickSparkle installed, registered for startup, and running from $exe"
