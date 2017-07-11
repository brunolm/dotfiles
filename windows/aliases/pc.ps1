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
        [console]::setcursorposition($saveX,$saveY+3)
    }
}

function Update-DNS() {
    $ips = ("127.0.0.1", "200.195.148.34", "8.8.8.8", "8.8.4.4");

    $wifiIndex = (Get-DnsClientServerAddress | Where-Object {$_.InterfaceAlias -eq 'Wi-Fi' -and $_.AddressFamily -eq 2} | Select-Object InterfaceIndex).InterfaceIndex
    $netIndex = (Get-DnsClientServerAddress | Where-Object {$_.InterfaceAlias -eq 'Ethernet' -and $_.AddressFamily -eq 2} | Select-Object InterfaceIndex).InterfaceIndex

    Set-DnsClientServerAddress -InterfaceIndex $wifiIndex -ServerAddresses $ips
    Set-DnsClientServerAddress -InterfaceIndex $netIndex -ServerAddresses $ips
}

function p() { Set-Location "D:\BrunoLM\Projects" }

Disable-Beep
