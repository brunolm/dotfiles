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

Disable-Beep
