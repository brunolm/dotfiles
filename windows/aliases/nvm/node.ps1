$env:NODE_DIR="C:\Program Files\nodejs";
$env:NODE_VERSIONS_DIR=(Join-Path $env:NODE_DIR "versions");

function nvm($command, [Switch] $help) {
    $commandPath = "$PSScriptRoot\commands\$command.ps1";

    if (!$command -or !(Test-Path $commandPath)) {
        Write-Host "Usage:"
        Write-Host -ForegroundColor Green "  nvm <command> <args>"

        Write-Host ""
        Write-Host "Available commands"

        foreach($_ in Get-ChildItem $PSScriptRoot\commands -Name) {
            if ($_ -ne "_base.ps1") {
                Write-Host -NoNewline "  "
                [System.IO.Path]::GetFileNameWithoutExtension($_)
            }
        }

        Write-Host ""
        Write-Host "Use -h or --help for info on each command"
        Write-Host ""
        return;
    }

    & "$commandPath" @args $(If ($help) {"--help"})
}
