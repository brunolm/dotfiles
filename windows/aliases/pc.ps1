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

# TODO: move to another file

function Kill-Port($port) {
  $processesOnPort = Get-NetTCPConnection -LocalPort $port -State Listen
  Write-Output $processesOnPort

  $connection = $processesOnPort | Select-Object -Property OwningProcess

  if ($connection.OwningProcess) {
    Stop-Process -Id $connection.OwningProcess
  }
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
