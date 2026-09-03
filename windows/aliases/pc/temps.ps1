# Live CPU/GPU temperature monitor. Sources, each skipped when unavailable:
# ACPI thermal zone (CPU package), Core Temp shared memory (per-core), the RAPL energy
# meter counters (package watts), nvidia-smi (GPU), and the MSI embedded controller
# (fan duty, needs an elevated shell).
function B-PC-Watch-Temps {
  param(
    [int]$RefreshSeconds = 3,
    [int]$WarnCelsius = 80,
    [int]$CriticalCelsius = 90,
    [string]$Log,
    [switch]$Once
  )

  $history = [System.Collections.Generic.List[object]]::new()
  $ec = PCTemps-EcInstance

  try {
    while ($true) {
      $sample = PCTemps-Sample $ec
      $history.Add($sample)
      if ($history.Count -gt 15) { $history.RemoveAt(0) }

      if ($Log) { PCTemps-Log $Log $sample }

      if (!$Once) { Clear-Host }
      PCTemps-Render $sample $history $RefreshSeconds $WarnCelsius $CriticalCelsius
      if ($Once) { return }

      Start-Sleep -Seconds $RefreshSeconds
    }
  }
  finally {
    if (!$Once) { Write-Host "`nStopped watching." -ForegroundColor DarkGray }
  }
}

function PCTemps-Sample($ec) {
  $sample = [ordered]@{ Time = Get-Date }
  PCTemps-Cpu $sample
  PCTemps-Gpu $sample
  PCTemps-Fans $sample $ec
  return [pscustomobject]$sample
}

function PCTemps-Cpu($sample) {
  $zone = Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($zone) { $sample.CpuC = [int]$zone.Temperature - 273 }

  $counters = Get-Counter -Counter @(
    '\Energy Meter(rapl_package0_pkg)\Power',
    '\Processor Information(_Total)\% Processor Performance',
    '\Processor Information(_Total)\Processor Frequency'
  ) -ErrorAction SilentlyContinue
  if ($counters) {
    $byPath = @{}
    foreach ($c in $counters.CounterSamples) { $byPath[($c.Path -replace '^.*\\', '')] = $c.CookedValue }
    if ($byPath.ContainsKey('power')) { $sample.CpuW = [math]::Round($byPath['power'] / 1000, 1) }
    if ($byPath.ContainsKey('processor frequency')) { $sample.CpuMHz = [int]($byPath['processor frequency'] * $byPath['% processor performance'] / 100) }
  }

  $cores = PCTemps-CoreTemp
  if (!$cores) { return }
  $sample.CoreMaxC = ($cores.Temps | Measure-Object -Maximum).Maximum
  $sample.CoresHot = @($cores.Temps | Where-Object { $_ -ge 50 }).Count
  $sample.CpuMHz = [int]$cores.MHz
}

# Core Temp shared-memory layout: uiLoad[256] uiTjMax[128] uiCoreCnt uiCPUCnt fTemp[256]
# fVID fCPUSpeed ... so core count sits at byte 1536, temps at 1544, CPU speed at 2572.
function PCTemps-CoreTemp {
  try {
    $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('CoreTempMappingObject')
    $view = $mmf.CreateViewAccessor(0, 4096)
    $buf = New-Object byte[] 4096
    $view.ReadArray(0, $buf, 0, 4096) | Out-Null
    $view.Dispose(); $mmf.Dispose()
  }
  catch { return $null }

  $count = [BitConverter]::ToUInt32($buf, 1536)
  if ($count -lt 1 -or $count -gt 256) { return $null }

  return [pscustomobject]@{
    Temps = 0..($count - 1) | ForEach-Object { [int][BitConverter]::ToSingle($buf, 1544 + $_ * 4) }
    MHz   = [BitConverter]::ToSingle($buf, 2572)
  }
}

function PCTemps-Gpu($sample) {
  if (!(Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { return }
  $line = & nvidia-smi --query-gpu=temperature.gpu,power.draw,utilization.gpu,clocks.sm,pstate --format=csv,noheader,nounits 2>$null
  if (!$line) { return }

  $parts = ($line -split ',') | ForEach-Object { $_.Trim() }
  $sample.GpuC = [int]$parts[0]
  $sample.GpuW = [math]::Round([double]$parts[1], 1)
  $sample.GpuPct = [int]$parts[2]
  $sample.GpuMHz = [int]$parts[3]
  $sample.GpuState = $parts[4]
}

function PCTemps-EcInstance {
  try { return @(([wmiclass]'root\wmi:MSI_ACPI').GetInstances())[0] } catch { return $null }
}

# MSI EC registers: 0x71 CPU fan duty %, 0x89 GPU fan duty %. Get_Data takes the address in
# Bytes[0] of a Package_32 and answers with the value in Bytes[1].
function PCTemps-Fans($sample, $ec) {
  if (!$ec) { return }
  try {
    $sample.FanCpu = PCTemps-EcRead $ec 0x71
    $sample.FanGpu = PCTemps-EcRead $ec 0x89
  }
  catch { }
}

function PCTemps-EcRead($ec, $address) {
  $package = ([wmiclass]'root\wmi:Package_32').CreateInstance()
  $bytes = New-Object byte[] 32
  $bytes[0] = [byte]$address
  $package.Bytes = $bytes

  $params = $ec.GetMethodParameters('Get_Data')
  $params.Data = $package
  return [int]$ec.InvokeMethod('Get_Data', $params, $null).Data.Bytes[1]
}

function PCTemps-Render($sample, $history, $refresh, $warn, $critical) {
  Write-Host ("Updated {0:HH:mm:ss}   refresh {1}s   warn {2}C   critical {3}C   Ctrl+C to stop" -f $sample.Time, $refresh, $warn, $critical) -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'CPU   ' -NoNewline
  PCTemps-WriteTemp $sample.CpuC 'package' $warn $critical
  if ($null -ne $sample.CoreMaxC) {
    PCTemps-WriteTemp $sample.CoreMaxC 'hottest core' $warn $critical
    Write-Host ("{0} cores >50C   " -f $sample.CoresHot) -NoNewline
  }
  if ($sample.CpuMHz) { Write-Host ("{0:N1} GHz   " -f ($sample.CpuMHz / 1000)) -NoNewline }
  if ($null -ne $sample.CpuW) { Write-Host ("{0} W" -f $sample.CpuW) -NoNewline }
  Write-Host ''

  if ($null -ne $sample.GpuC) {
    Write-Host 'GPU   ' -NoNewline
    PCTemps-WriteTemp $sample.GpuC '' $warn $critical
    Write-Host ("{0} W   {1}%   {2} MHz   {3}" -f $sample.GpuW, $sample.GpuPct, $sample.GpuMHz, $sample.GpuState)
  }

  if ($null -ne $sample.FanCpu) {
    Write-Host ("Fans  cpu {0}%   gpu {1}%" -f $sample.FanCpu, $sample.FanGpu)
  }

  if ($history.Count -lt 2) { return }
  Write-Host ''
  foreach ($row in $history) {
    $line = "{0:HH:mm:ss}  CPU {1,3}C" -f $row.Time, $row.CpuC
    if ($null -ne $row.CoreMaxC) { $line += "  core {0,3}C" -f $row.CoreMaxC }
    if ($null -ne $row.GpuC) { $line += "  GPU {0,3}C" -f $row.GpuC }
    if ($null -ne $row.CpuW) { $line += "  {0,5} W" -f $row.CpuW }
    Write-Host $line -ForegroundColor (PCTemps-Color ([Math]::Max([int]$row.CpuC, [int]$row.CoreMaxC)) $warn $critical)
  }
}

function PCTemps-WriteTemp($value, $label, $warn, $critical) {
  if ($null -eq $value) { return }
  $text = if ($label) { "{0} {1}C   " -f $label, $value } else { "{0}C   " -f $value }
  Write-Host $text -NoNewline -ForegroundColor (PCTemps-Color $value $warn $critical)
}

function PCTemps-Color($value, $warn, $critical) {
  if ($value -ge $critical) { return 'Red' }
  if ($value -ge $warn) { return 'Yellow' }
  return 'Green'
}

function PCTemps-Log($path, $sample) {
  if (!(Test-Path $path)) {
    'time,cpu_c,core_max_c,cpu_w,cpu_mhz,gpu_c,gpu_w,gpu_pct,gpu_mhz,fan_cpu,fan_gpu' | Set-Content $path
  }
  $row = @(
    ('{0:yyyy-MM-dd HH:mm:ss}' -f $sample.Time), $sample.CpuC, $sample.CoreMaxC, $sample.CpuW, $sample.CpuMHz,
    $sample.GpuC, $sample.GpuW, $sample.GpuPct, $sample.GpuMHz, $sample.FanCpu, $sample.FanGpu
  ) -join ','
  Add-Content $path $row
}
