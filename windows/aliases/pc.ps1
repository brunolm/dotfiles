function Disable-Beep() {
  Set-PSReadlineOption -BellStyle None
  # set-service beep -startuptype disabled
}

function Start-Powershell() {
  Start-Process powershell -Verb runAs
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

function Update-DNS($ips, $id) {
  # Foticlient
  # 172.23.1.1, 172.23.1.10

  if (!$ips) {
    $ips = ("2001:4860:4860:0:0:0:0:8888", "2001:4860:4860:0:0:0:0:8844", "8.8.8.8", "8.8.4.4", "208.67.222.222", "208.67.220.220", "1.1.1.1", "127.0.0.1");
    # $ips = ("1.1.1.1", "8.8.8.8", "8.8.4.4", "200.195.148.34", "127.0.0.1");
  }

  if (!$id) {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses -ne "" } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
  else {
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.InterfaceIndex -eq $id } | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
  }
}

function Kill-Port($port) {
  $processesOnPort = Get-NetTCPConnection -LocalPort $port -State Listen
  Write-Output $processesOnPort

  $connection = $processesOnPort | Select-Object -Property OwningProcess

  if ($connection.OwningProcess) {
    Stop-Process -Id $connection.OwningProcess
  }
}

function p() { Set-Location "D:\BrunoLM\Projects" }
function pc() { Set-Location "C:\BrunoLM\Projects" }

function which($p) {
  (Get-Command $p).Definition
}

Disable-Beep
