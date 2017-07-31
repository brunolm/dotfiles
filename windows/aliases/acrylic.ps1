function Acrylic-Purge() {
    Start-Process "C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicController.exe" "PurgeAcrylicCacheData"
}

function Acrylic-Stop() {
    Start-Process "C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicController.exe" "StopAcrylicService"
}

function Acrylic-Start() {
    Start-Process "C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicController.exe" "StartAcrylicService"
}

function Acrylic-EditHosts() {
    Start-Process "C:\Program Files (x86)\Acrylic DNS Proxy\AcrylicController.exe" "EditAcrylicHostsFile"
}
