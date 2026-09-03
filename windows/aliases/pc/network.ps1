function B-PC-Update-DNS($ips, $id) {
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

function B-PC-Network-RestartEthernet() {
  Disable-NetAdapter -Name "Ethernet" -Confirm:$false
  Start-Sleep -Seconds 2
  Enable-NetAdapter -Name "Ethernet" -Confirm:$false
}
