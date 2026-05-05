function Kill-Node() {
    Get-WmiObject -Query "select * from win32_process where name = 'node.exe'" | Remove-WmiObject
}
