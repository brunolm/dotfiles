function Stop-Port($port) {
    $p = Get-Process -Id (Get-NetTCPConnection -LocalPort $port).OwningProcess

    Stop-Process -Id $p.Id
}
