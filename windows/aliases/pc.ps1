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

function Update-DNS($ips, $id) {
    # Foticlient
    # 172.23.1.1, 172.23.1.10

    if (!$ips) {
        $ips = ("127.0.0.1", "8.8.8.8", "8.8.4.4", "200.195.148.34");
    }

    if (!$id) {
        Get-DnsClientServerAddress | Where-Object {$_.AddressFamily -eq 2} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
    }
    else {
        Get-DnsClientServerAddress | Where-Object {$_.AddressFamily -eq 2 -and $_.InterfaceIndex -eq $id} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips }
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

Disable-Beep
