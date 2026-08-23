function PC-Disable-Beep() {
  Set-PSReadlineOption -BellStyle None
  # set-service beep -startuptype disabled
}

function PC-Start-Powershell() {
  Start-Process powershell -Verb runAs
}

function PC-Update-DNS($ips, $id) {
  # Foticlient
  # 172.23.1.1, 172.23.1.10

  if (!$ips) {
    $ips = ("2001:4860:4860:0:0:0:0:8888", "2001:4860:4860:0:0:0:0:8844", "8.8.8.8", "8.8.4.4", "208.67.222.222", "208.67.220.220", "1.1.1.1", "127.0.0.1");
    # $ips = ("127.0.0.1");
  }

  if (!$id) {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses -ne "" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
  else {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.InterfaceIndex -eq $id } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
}

function PC-Network-RestartEthernet() {
  Disable-NetAdapter -Name "Ethernet" -Confirm:$false
  Start-Sleep -Seconds 2
  Enable-NetAdapter -Name "Ethernet" -Confirm:$false
}

function PC-Disable-RealtimeProtection() {
  Set-MpPreference -DisableRealtimeMonitoring $true
}

# NVMe link/idle power settings. Aggressive ASPM L1 plus a short disk idle timeout
# can leave the controller unresponsive on wake; "original" is what the machine shipped with.
function PC-Set-PowerProfile($preset) {
  $presets = @{
    power    = @{ AspmAc = 1; AspmDc = 2; DiskIdleAc = 900; DiskIdleDc = 60 }
    original = @{ AspmAc = 2; AspmDc = 2; DiskIdleAc = 30; DiskIdleDc = 60 }
  }

  if (!$preset -or !$presets.ContainsKey($preset)) {
    Write-Error "Usage: PC-Set-PowerProfile <$($presets.Keys -join '|')>"
    return
  }

  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (!([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Needs an elevated shell - run PC-Start-Powershell first."
    return
  }

  $p = $presets[$preset]

  powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM $p.AspmAc
  powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM $p.AspmDc
  powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE $p.DiskIdleAc
  powercfg /setdcvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE $p.DiskIdleDc
  powercfg /setactive SCHEME_CURRENT

  $aspmNames = @{ 0 = 'Off'; 1 = 'Moderate'; 2 = 'Maximum' }
  Write-Host "Applied '$preset':"
  Write-Host "  ASPM      AC: $($aspmNames[$p.AspmAc])  DC: $($aspmNames[$p.AspmDc])"
  Write-Host "  DiskIdle  AC: $($p.DiskIdleAc)s  DC: $($p.DiskIdleDc)s"
}

function psl() {
  $saveY = [console]::CursorTop
  $saveX = [console]::CursorLeft

  while ($true) {
    Get-Process | Sort-Object -Descending CPU | Select-Object -First 30;
    Start-Sleep -Seconds 2;
    [console]::setcursorposition($saveX, $saveY + 3)
  }
}

function which($p) {
  (Get-Command $p).Definition
}


PC-Disable-Beep
