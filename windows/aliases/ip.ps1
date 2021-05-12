function Get-IPExternal() {
    (Invoke-WebRequest ifconfig.me/ip).Content.Trim()
}
